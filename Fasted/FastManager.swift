import Foundation
import CoreData
import SwiftUI

@MainActor
public final class FastManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    public let notificationManager: NotificationManager

    @Published public private(set) var activeFast: Fast?
    @Published public private(set) var userSettings: UserSettings?

    public init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        notificationManager: NotificationManager = .shared
    ) {
        self.viewContext = context
        self.notificationManager = notificationManager
        self.setupNotificationCallbacks()
        self.refresh()
    }

    private func setupNotificationCallbacks() {
        notificationManager.onEndFastRequested = { [weak self] in
            Task { @MainActor [weak self] in
                self?.endFast()
            }
        }
        notificationManager.onSnoozeRequested = { [weak self] snoozeSeconds in
            Task { @MainActor [weak self] in
                self?.snoozeFast(by: snoozeSeconds)
            }
        }
    }

    public func refresh() {
        fetchActiveFast()
        fetchUserSettings()
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
        } catch {
            NSLog("Error saving protocol setting: \(error)")
        }
    }

    public func updateNotificationSchedule(enabled: Bool, schedule: NotificationSchedule) {
        guard let settings = userSettings else { return }
        settings.notificationsEnabled = enabled

        if let encoded = try? JSONEncoder().encode(schedule) {
            settings.notificationSchedule = encoded
        }

        do {
            try viewContext.save()
            self.objectWillChange.send()

            notificationManager.scheduleRecurringReminders(schedule: schedule, enabled: enabled)
        } catch {
            NSLog("Error updating notification settings: \(error)")
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
            notificationManager.scheduleGoalNotification(targetEndDate: targetEnd, protocolName: proto)
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
            self.activeFast = nil
            notificationManager.cancelGoalNotification()
        } catch {
            NSLog("Error ending fast: \(error)")
        }
    }

    public func updateActiveFast(startDate: Date, targetDuration: TimeInterval? = nil) {
        guard let fast = activeFast else { return }
        fast.startDate = startDate
        if let duration = targetDuration {
            fast.targetDuration = duration
        }
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.objectWillChange.send()

            let targetEnd = startDate.addingTimeInterval(fast.targetDuration)
            let proto = fast.protocolType ?? "16:8"
            notificationManager.scheduleGoalNotification(targetEndDate: targetEnd, protocolName: proto)
        } catch {
            NSLog("Error updating active fast: \(error)")
        }
    }

    public func snoozeFast(by extensionSeconds: TimeInterval) {
        guard let fast = activeFast else { return }
        fast.targetDuration += extensionSeconds
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.objectWillChange.send()

            let start = fast.startDate ?? Date()
            let targetEnd = start.addingTimeInterval(fast.targetDuration)
            let proto = fast.protocolType ?? "16:8"
            notificationManager.scheduleGoalNotification(targetEndDate: targetEnd, protocolName: proto)
        } catch {
            NSLog("Error snoozing fast: \(error)")
        }
    }

    public func updateCompletedFast(
        _ fast: Fast,
        startDate: Date,
        endDate: Date
    ) {
        fast.startDate = startDate
        fast.endDate = endDate
        let elapsed = endDate.timeIntervalSince(startDate)
        fast.isCompleted = (elapsed >= fast.targetDuration)
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.objectWillChange.send()
        } catch {
            NSLog("Error updating completed fast: \(error)")
        }
    }

    public func deleteFast(_ fast: Fast) {
        if activeFast?.id == fast.id {
            activeFast = nil
            notificationManager.cancelGoalNotification()
        }
        viewContext.delete(fast)

        do {
            try viewContext.save()
            self.objectWillChange.send()
        } catch {
            NSLog("Error deleting fast: \(error)")
        }
    }

    public func validateInterval(
        startDate: Date,
        endDate: Date? = nil,
        excludingFastId: UUID? = nil
    ) -> (isValid: Bool, message: String?) {
        let now = Date()
        if startDate > now {
            return (false, "Start time cannot be in the future.")
        }
        if let end = endDate, end > now {
            return (false, "End time cannot be in the future.")
        }
        if let end = endDate, end <= startDate {
            return (false, "End time must be after the start time.")
        }

        let effectiveEnd = endDate ?? now
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        if let excludeId = excludingFastId {
            request.predicate = NSPredicate(format: "id != %@", excludeId as CVarArg)
        }

        guard let allFasts = try? viewContext.fetch(request) else {
            return (true, nil)
        }

        for other in allFasts {
            guard let otherStart = other.startDate else { continue }
            let otherEnd = other.endDate ?? now
            if startDate < otherEnd && effectiveEnd > otherStart {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return (false, "This time overlaps with another fast on \(formatter.string(from: otherStart)).")
            }
        }
        return (true, nil)
    }

    public func clearAllFastingData() {
        let request: NSFetchRequest<NSFetchRequestResult> = Fast.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [viewContext]
                )
            }
            activeFast = nil
            notificationManager.cancelGoalNotification()
            notificationManager.cancelRecurringReminders()
            self.objectWillChange.send()
        } catch {
            NSLog("Error clearing all fasting data: \(error)")
        }
    }
}
