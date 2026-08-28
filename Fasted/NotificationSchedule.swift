import Foundation

public struct NotificationSchedule: Codable, Equatable {
    public var startReminderTime: Date
    /// No longer surfaced in the UI (the "Eating Window Open" reminder was removed — it fired on a
    /// fixed wall-clock schedule unrelated to any actual fast). Kept so existing persisted
    /// `NotificationSchedule` blobs continue to decode without resetting the rest of the schedule.
    public var endReminderTime: Date
    public var selectedDays: Set<Int> // 1=Sunday, 2=Monday, ..., 7=Saturday
    public var notifyOnGoalReached: Bool

    public init(
        startReminderTime: Date,
        endReminderTime: Date,
        selectedDays: Set<Int>,
        notifyOnGoalReached: Bool = true
    ) {
        self.startReminderTime = startReminderTime
        self.endReminderTime = endReminderTime
        self.selectedDays = selectedDays
        self.notifyOnGoalReached = notifyOnGoalReached
    }

    public static var `default`: NotificationSchedule {
        let calendar = Calendar.current
        let now = Date()
        let startTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now // 8:00 PM
        let endTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now // 12:00 PM

        return NotificationSchedule(
            startReminderTime: startTime,
            endReminderTime: endTime,
            selectedDays: Set(1...7),
            notifyOnGoalReached: true
        )
    }
}
