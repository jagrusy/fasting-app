import Foundation
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    public static let goalReachedCategoryId = "FAST_GOAL_CATEGORY"
    public static let endFastActionId = "END_FAST_ACTION"
    public static let snooze30MinActionId = "SNOOZE_30MIN_ACTION"
    public static let snooze1HourActionId = "SNOOZE_1HOUR_ACTION"

    public static let startFastCategoryId = "START_FAST_CATEGORY"
    public static let startFastActionId = "START_FAST_ACTION"

    public var onStartFastRequested: (@MainActor () -> Void)?
    public var onEndFastRequested: (@MainActor () -> Void)?
    public var onSnoozeRequested: (@MainActor (TimeInterval) -> Void)?

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

        let goalCategory = UNNotificationCategory(
            identifier: NotificationManager.goalReachedCategoryId,
            actions: [endAction, snooze30, snooze1h],
            intentIdentifiers: [],
            options: []
        )

        let startAction = UNNotificationAction(
            identifier: NotificationManager.startFastActionId,
            title: "Start Fast",
            options: [.authenticationRequired]
        )

        let startCategory = UNNotificationCategory(
            identifier: NotificationManager.startFastCategoryId,
            actions: [startAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([goalCategory, startCategory])
    }

    public func scheduleGoalNotification(targetEndDate: Date, protocolName: String, enabled: Bool = true) {
        cancelGoalNotification()
        guard enabled else { return }

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

        for day in schedule.selectedDays {
            scheduleDayReminder(
                weekday: day,
                time: (startComponents.hour ?? 20, startComponents.minute ?? 0),
                title: "Time to Start Fasting ⏱️",
                body: "Your fasting window starts now. Have a great fast!",
                identifier: "recurring_start_day_\(day)",
                categoryIdentifier: NotificationManager.startFastCategoryId
            )
        }
    }

    private func scheduleDayReminder(
        weekday: Int,
        time: (hour: Int, minute: Int),
        title: String,
        body: String,
        identifier: String,
        categoryIdentifier: String? = nil
    ) {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Failed to schedule reminder \(identifier): \(error)")
            }
        }
    }

    public func cancelRecurringReminders() {
        // `recurring_end_day_*` is no longer scheduled, but builds shipped before it was removed
        // may still have those requests pending — keep cancelling them or they fire forever.
        let identifiers = (1...7).flatMap { [
            "recurring_start_day_\($0)",
            "recurring_end_day_\($0)"
        ] }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Stage Transition Notifications

    public struct StageBoundary: Equatable {
        public let stage: MetabolicStage
        public let fireDate: Date
        public let timeInterval: TimeInterval

        public init(stage: MetabolicStage, fireDate: Date, timeInterval: TimeInterval) {
            self.stage = stage
            self.fireDate = fireDate
            self.timeInterval = timeInterval
        }
    }

    public static func stageNotificationIdentifier(for stage: MetabolicStage) -> String {
        "fast_stage_\(stage.rawValue)"
    }

    public static func futureStageBoundaries(
        startDate: Date,
        now: Date = Date()
    ) -> [StageBoundary] {
        MetabolicStage.allCases
            .filter { $0.startSeconds > 0 }
            .compactMap { stage in
                let fireDate = startDate.addingTimeInterval(stage.startSeconds)
                let interval = fireDate.timeIntervalSince(now)
                guard interval > 0 else { return nil }
                return StageBoundary(stage: stage, fireDate: fireDate, timeInterval: interval)
            }
    }

    public func scheduleStageTransitionNotifications(
        startDate: Date,
        enabled: Bool = true,
        now: Date = Date()
    ) {
        cancelStageTransitionNotifications()
        guard enabled else { return }

        let boundaries = Self.futureStageBoundaries(startDate: startDate, now: now)
        for item in boundaries {
            let content = UNMutableNotificationContent()
            content.title = item.stage.title
            content.body = item.stage.summary
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.timeInterval, repeats: false)
            let identifier = Self.stageNotificationIdentifier(for: item.stage)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    NSLog("Failed to schedule stage notification \(identifier): \(error)")
                }
            }
        }
    }

    public func cancelStageTransitionNotifications() {
        let identifiers = MetabolicStage.allCases.map { Self.stageNotificationIdentifier(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationManager.startFastActionId:
            DispatchQueue.main.async { [weak self] in
                self?.onStartFastRequested?()
            }
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
