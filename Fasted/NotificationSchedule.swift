import Foundation

public struct NotificationSchedule: Codable, Equatable {
    public var startReminderTime: Date
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
        var startComponents = DateComponents()
        startComponents.hour = 20 // 8:00 PM
        startComponents.minute = 0

        var endComponents = DateComponents()
        endComponents.hour = 12 // 12:00 PM
        endComponents.minute = 0

        let now = Date()
        let startTime = calendar.date(from: startComponents) ?? now
        let endTime = calendar.date(from: endComponents) ?? now

        return NotificationSchedule(
            startReminderTime: startTime,
            endReminderTime: endTime,
            selectedDays: Set(1...7),
            notifyOnGoalReached: true
        )
    }
}
