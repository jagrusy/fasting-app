import Foundation
import CoreData
import SwiftUI

@MainActor
public final class FastManager: ObservableObject {
    let viewContext: NSManagedObjectContext
    public let notificationManager: NotificationManager
    let defaults: UserDefaults
    public let coordinator: AppGroupCoordinator
    private var darwinObserverToken: DarwinNotificationCenter.ObserverToken?

    @Published public internal(set) var activeFast: Fast?
    @Published public internal(set) var userSettings: UserSettings?

    public init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        notificationManager: NotificationManager = .shared,
        defaults: UserDefaults = .standard,
        coordinator: AppGroupCoordinator = .shared
    ) {
        self.viewContext = context
        self.notificationManager = notificationManager
        self.defaults = defaults
        self.coordinator = coordinator
        self.setupNotificationCallbacks()
        self.setupDarwinObserver()
        self.refresh()
    }

    private func setupDarwinObserver() {
        darwinObserverToken = DarwinNotificationCenter.shared.observe { [weak self] in
            Task { @MainActor [weak self] in
                self?.processPendingCommands()
            }
        }
    }

    private func setupNotificationCallbacks() {
        notificationManager.onStartFastRequested = { [weak self] in
            self?.startFast()
        }
        notificationManager.onEndFastRequested = { [weak self] in
            self?.endFast()
        }
        notificationManager.onSnoozeRequested = { [weak self] snoozeSeconds in
            self?.snoozeFast(by: snoozeSeconds)
        }
    }

    public func refresh() {
        fetchActiveFast()
        fetchUserSettings()
        processPendingCommands()
        publishSnapshot()
    }

    public func fetchActiveFast() {
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()

        request.predicate = NSPredicate(format: "endDate == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Fast.startDate, ascending: false)]
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            self.activeFast = results.first
        } catch {
            NSLog("Failed to fetch active fast: \(error)")
            self.activeFast = nil
        }
    }

    public func fetchUserSettings() {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            if let existing = results.first {
                self.userSettings = existing
            } else {
                self.userSettings = createDefaultUserSettings()
            }
        } catch {
            NSLog("Failed to fetch UserSettings: \(error)")
        }
    }

    private func createDefaultUserSettings() -> UserSettings {
        let initial = UserSettings(context: viewContext)
        initial.id = UUID()
        initial.selectedProtocol = FastingProtocol.default.ratioString
        initial.notificationsEnabled = false
        try? viewContext.save()
        return initial
    }

    public var currentProtocol: FastingProtocol {
        FastingProtocol.from(protocolType: userSettings?.selectedProtocol)
    }

    /// The active fast's own protocol, independent of the current settings selection.
    /// Use this (not `currentProtocol`) anywhere an in-progress or completed fast is displayed,
    /// since `currentProtocol` reflects Settings and can diverge from what a specific fast is tracking.
    public func protocolForActiveFast() -> FastingProtocol? {
        guard let fast = activeFast else { return nil }
        return FastingProtocol.from(protocolType: fast.protocolType)
    }

    public var isFasting: Bool {
        activeFast != nil
    }

    public var notificationSchedule: NotificationSchedule {
        guard let data = userSettings?.notificationSchedule,
              let decoded = try? JSONDecoder().decode(NotificationSchedule.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func updateSelectedProtocol(_ protocolType: String) {
        guard let settings = userSettings else { return }
        settings.selectedProtocol = protocolType

        do {
            try viewContext.save()
            self.objectWillChange.send()
            publishSnapshot()
        } catch {
            NSLog("Error saving protocol setting: \(error)")
        }
    }

    @discardableResult
    public func startFast(
        startDate: Date = Date(),
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil
    ) -> Fast {
        if let existing = activeFast {
            return existing
        }

        let proto = protocolType ?? currentProtocol.ratioString
        let duration = targetDuration ?? FastingProtocol.from(protocolType: proto).fastingSeconds

        let fast = Fast(context: viewContext)
        fast.id = UUID()
        fast.startDate = startDate
        fast.targetDuration = duration
        fast.protocolType = proto
        fast.isCompleted = false
        fast.createdAt = Date()
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.activeFast = fast

            let targetEnd = startDate.addingTimeInterval(duration)
            notificationManager.scheduleGoalNotification(
                targetEndDate: targetEnd,
                protocolName: proto,
                enabled: notificationSchedule.notifyOnGoalReached
            )
            notificationManager.scheduleStageTransitionNotifications(
                startDate: startDate,
                enabled: notificationSchedule.notifyOnStageChange
            )
            publishSnapshot()
        } catch {
            NSLog("Error starting fast: \(error)")
        }
        return fast
    }

    public func endFast(endDate: Date = Date(), moodRating: Int16? = nil) {
        guard let fast = activeFast else { return }

        let start = fast.startDate ?? Date()
        fast.endDate = endDate
        fast.isCompleted = (endDate.timeIntervalSince(start) >= fast.targetDuration)
        if let mood = moodRating {
            fast.moodRating = mood
        }
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            let completed = fast
            self.activeFast = nil
            notificationManager.cancelGoalNotification()
            notificationManager.cancelStageTransitionNotifications()
            clearSnoozeOffset(for: fast)
            publishSnapshot()

            let request: NSFetchRequest<Fast> = Fast.fetchRequest()
            request.predicate = NSPredicate(format: "endDate != nil AND isCompleted == YES")
            let allCompleted = (try? viewContext.fetch(request)) ?? []
            ReviewPromptManager.shared.checkAndPromptIfEligible(
                completedFast: completed,
                allCompletedFasts: allCompleted
            )
        } catch {
            NSLog("Error ending fast: \(error)")
        }
    }

    public func updateActiveFast(

        startDate: Date,
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil
    ) {
        guard let fast = activeFast else { return }
        fast.startDate = startDate
        if let duration = targetDuration {
            fast.targetDuration = duration
        }
        if let proto = protocolType {
            fast.protocolType = proto
        }
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.objectWillChange.send()

            let targetEnd = startDate.addingTimeInterval(fast.targetDuration + snoozeOffset(for: fast))
            let proto = fast.protocolType ?? FastingProtocol.default.ratioString
            notificationManager.scheduleGoalNotification(
                targetEndDate: targetEnd,
                protocolName: proto,
                enabled: notificationSchedule.notifyOnGoalReached
            )
            notificationManager.scheduleStageTransitionNotifications(
                startDate: startDate,
                enabled: notificationSchedule.notifyOnStageChange
            )
            publishSnapshot()
        } catch {
            NSLog("Error updating active fast: \(error)")
        }
    }

    public func snoozeFast(by extensionSeconds: TimeInterval) {
        guard let fast = activeFast, let id = fast.id else { return }
        let newOffset = defaults.double(forKey: snoozeOffsetKey(for: id)) + extensionSeconds
        defaults.set(newOffset, forKey: snoozeOffsetKey(for: id))

        let start = fast.startDate ?? Date()
        let targetEnd = start.addingTimeInterval(fast.targetDuration + newOffset)
        let proto = fast.protocolType ?? FastingProtocol.default.ratioString
        notificationManager.scheduleGoalNotification(
            targetEndDate: targetEnd,
            protocolName: proto,
            enabled: notificationSchedule.notifyOnGoalReached
        )
        publishSnapshot()
    }
}
