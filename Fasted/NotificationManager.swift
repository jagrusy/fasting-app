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
