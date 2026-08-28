import Foundation

extension FastManager {
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
            rescheduleGoalNotificationForActiveFast(notifyOnGoalReached: schedule.notifyOnGoalReached)
        } catch {
            NSLog("Error updating notification settings: \(error)")
        }
    }

    /// Re-registers all notifications from current state. Call on launch / foreground so a goal
    /// notification lost to a late permission grant, or a recurring reminder pruned by iOS, recovers,
    /// and so that any reminder identifiers retired in a previous app version get purged.
    public func syncNotifications() {
        let schedule = notificationSchedule
        notificationManager.scheduleRecurringReminders(
            schedule: schedule,
            enabled: userSettings?.notificationsEnabled ?? false
        )
        rescheduleGoalNotificationForActiveFast(notifyOnGoalReached: schedule.notifyOnGoalReached)
    }

    func rescheduleGoalNotificationForActiveFast(notifyOnGoalReached: Bool) {
        guard let fast = activeFast, let start = fast.startDate else { return }
        let targetEnd = start.addingTimeInterval(fast.targetDuration + snoozeOffset(for: fast))
        let proto = fast.protocolType ?? FastingProtocol.default.ratioString
        notificationManager.scheduleGoalNotification(
            targetEndDate: targetEnd,
            protocolName: proto,
            enabled: notifyOnGoalReached
        )
    }

    // MARK: - Snooze offset

    /// Snoozing must not rewrite a fast's `targetDuration` (that field also drives the completion
    /// percentage and streak math), but the extra delay still needs to survive the app being
    /// backgrounded when the notification fires. Stored in UserDefaults, keyed per fast, and cleared
    /// whenever that fast stops being active.
    private static let snoozeOffsetKeyPrefix = "com.solstice.snoozeOffset."

    func snoozeOffsetKey(for fastId: UUID) -> String {
        "\(Self.snoozeOffsetKeyPrefix)\(fastId.uuidString)"
    }

    func snoozeOffset(for fast: Fast) -> TimeInterval {
        guard let id = fast.id else { return 0 }
        return defaults.double(forKey: snoozeOffsetKey(for: id))
    }

    func clearSnoozeOffset(for fast: Fast) {
        guard let id = fast.id else { return }
        defaults.removeObject(forKey: snoozeOffsetKey(for: id))
    }

    /// Removes every stored snooze offset. Used when all fasting history is being erased, since the
    /// individual fast records (and their ids) are about to disappear via a batch delete.
    func clearAllSnoozeOffsets() {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(Self.snoozeOffsetKeyPrefix) }
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}
