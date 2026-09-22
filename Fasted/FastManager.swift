import Foundation
import CoreData
import SwiftUI

public struct FastManagerOperationError: Identifiable, Equatable {
    public let id = UUID()
    public let message: String

    init(message: String) {
        self.message = message
    }
}

@MainActor
public final class FastManager: ObservableObject {
    let viewContext: NSManagedObjectContext
    let persistence: FastManagerPersistence
    public let notificationManager: NotificationManager
    let defaults: UserDefaults
    public let coordinator: AppGroupCoordinator
    private var darwinObserverToken: DarwinNotificationCenter.ObserverToken?
    /// Guards `processPendingCommands()` — the scene-phase hook and the Darwin observer can both
    /// fire for the same enqueue.
    var isDrainingCommands = false

    @Published public internal(set) var activeFast: Fast?
    @Published public internal(set) var userSettings: UserSettings?
    @Published public internal(set) var operationError: FastManagerOperationError?

    public convenience init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        notificationManager: NotificationManager = .shared,
        defaults: UserDefaults = .standard,
        coordinator: AppGroupCoordinator = .shared
    ) {
        self.init(
            context: context,
            notificationManager: notificationManager,
            defaults: defaults,
            coordinator: coordinator,
            persistence: FastManagerPersistence(context: context)
        )
    }

    init(
        context: NSManagedObjectContext,
        notificationManager: NotificationManager = .shared,
        defaults: UserDefaults = .standard,
        coordinator: AppGroupCoordinator = .shared,
        persistence: FastManagerPersistence
    ) {
        self.viewContext = context
        self.persistence = persistence
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
            _ = self?.startFast()
        }
        notificationManager.onEndFastRequested = { [weak self] in
            self?.endFast()
        }
        notificationManager.onSnoozeRequested = { [weak self] snoozeSeconds in
            self?.snoozeFast(by: snoozeSeconds)
        }
    }

    /// Order matters: pending commands are applied against freshly-fetched state, and the
    /// snapshot every other surface reads is rewritten from Core Data last, so an optimistic
    /// write from a widget or the watch is always overwritten by the authoritative value.
    public func refresh() {
        guard fetchActiveFast(), fetchUserSettings() else { return }
        processPendingCommands()
        publishSnapshot()
    }

    @discardableResult
    public func fetchActiveFast() -> Bool {
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        request.predicate = NSPredicate(format: "endDate == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Fast.startDate, ascending: false)]
        request.fetchLimit = 1

        do {
            let results = try persistence.fetchFasts(request)
            self.activeFast = results.first
            return true
        } catch {
            return fail(error, operation: "Load the active fast", rollback: false)
        }
    }

    @discardableResult
    public func fetchUserSettings() -> Bool {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.fetchLimit = 1

        do {
            let results = try persistence.fetchSettings(request)
            if let existing = results.first {
                self.userSettings = existing
                return true
            } else {
                guard let settings = createDefaultUserSettings() else { return false }
                self.userSettings = settings
                return true
            }
        } catch {
            return fail(error, operation: "Load settings", rollback: false)
        }
    }

    private func createDefaultUserSettings() -> UserSettings? {
        let initial = UserSettings(context: viewContext)
        initial.id = UUID()
        initial.selectedProtocol = FastingProtocol.default.ratioString
        initial.notificationsEnabled = false
        do {
            try persistence.save()
            return initial
        } catch {
            _ = fail(error, operation: "Create settings")
            return nil
        }
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

    @discardableResult
    public func startFast(
        startDate: Date = Date(),
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil
    ) -> Fast? {
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
            try persistence.save()
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
            return fast
        } catch {
            _ = fail(error, operation: "Start the fast")
            return nil
        }
    }

    @discardableResult
    public func endFast(endDate: Date = Date(), moodRating: Int16? = nil) -> Bool {
        guard let fast = activeFast else { return false }

        fast.endDate = endDate
        fast.isCompleted = fast.hasReachedTarget()
        if let mood = moodRating {
            fast.moodRating = mood
        }
        fast.updatedAt = Date()

        do {
            try persistence.save()
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
            return true
        } catch {
            return fail(error, operation: "End the fast")
        }
    }

    @discardableResult
    public func updateActiveFast(
        startDate: Date,
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil
    ) -> Bool {
        guard let fast = activeFast else { return false }
        fast.startDate = startDate
        if let duration = targetDuration {
            fast.targetDuration = duration
        }
        if let proto = protocolType {
            fast.protocolType = proto
        }
        fast.updatedAt = Date()

        do {
            try persistence.save()
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
            return true
        } catch {
            return fail(error, operation: "Update the active fast")
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
