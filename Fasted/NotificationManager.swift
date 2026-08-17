import Foundation
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    public static let goalReachedCategoryId = "FAST_GOAL_CATEGORY"
    public static let endFastActionId = "END_FAST_ACTION"
    public static let snooze30MinActionId = "SNOOZE_30MIN_ACTION"
    public static let snooze1HourActionId = "SNOOZE_1HOUR_ACTION"

    public var onEndFastRequested: (() -> Void)?
    public var onSnoozeRequested: ((TimeInterval) -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    public func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("Notification authorization error: \(error)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    public func registerCategories() {
        let endAction = UNNotificationAction(
            identifier: NotificationManager.endFastActionId,
            title: "End Fast",
            options: [.destructive, .authenticationRequired]
        )

        let snooze30 = UNNotificationAction(
            identifier: NotificationManager.snooze30MinActionId,
            title: "Snooze (30m)",
            options: []
        )

        let snooze1h = UNNotificationAction(
            identifier: NotificationManager.snooze1HourActionId,
            title: "Snooze (1h)",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: NotificationManager.goalReachedCategoryId,
            actions: [endAction, snooze30, snooze1h],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func scheduleGoalNotification(targetEndDate: Date, protocolName: String) {
        cancelGoalNotification()

        let timeInterval = targetEndDate.timeIntervalSinceNow
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fasting Goal Reached! 🎉"
        content.body = "You completed your \(protocolName) fast. Ready to break your fast?"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.goalReachedCategoryId

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "fast_goal_notification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Failed to schedule goal notification: \(error)")
            }
        }
    }

    public func cancelGoalNotification() {
        let identifiers = ["fast_goal_notification"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func scheduleRecurringReminders(schedule: NotificationSchedule, enabled: Bool) {
        cancelRecurringReminders()
        guard enabled else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: schedule.startReminderTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: schedule.endReminderTime)

        for day in schedule.selectedDays {
            scheduleDayReminder(
                weekday: day,
                time: (startComponents.hour ?? 20, startComponents.minute ?? 0),
                title: "Time to Start Fasting ⏱️",
                body: "Your fasting window starts now. Have a great fast!",
                identifier: "recurring_start_day_\(day)"
            )

            scheduleDayReminder(
                weekday: day,
                time: (endComponents.hour ?? 12, endComponents.minute ?? 0),
                title: "Eating Window Open 🍽️",
                body: "Your eating window is now open. Time to nourish your body!",
                identifier: "recurring_end_day_\(day)"
            )
        }
    }

    private func scheduleDayReminder(
        weekday: Int,
        time: (hour: Int, minute: Int),
        title: String,
        body: String,
        identifier: String
    ) {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Failed to schedule reminder \(identifier): \(error)")
            }
        }
    }

    public func cancelRecurringReminders() {
        let identifiers = (1...7).flatMap { [
            "recurring_start_day_\($0)",
            "recurring_end_day_\($0)"
        ] }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationManager.endFastActionId:
            DispatchQueue.main.async { [weak self] in
                self?.onEndFastRequested?()
            }
        case NotificationManager.snooze30MinActionId:
            DispatchQueue.main.async { [weak self] in
                self?.onSnoozeRequested?(30 * 60)
            }
        case NotificationManager.snooze1HourActionId:
            DispatchQueue.main.async { [weak self] in
                self?.onSnoozeRequested?(60 * 60)
            }
        default:
            break
        }
        completionHandler()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
