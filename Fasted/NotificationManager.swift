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

    public func scheduleRecurringReminders(
        schedule: NotificationSchedule,
        enabled: Bool,
        suppressUntil: Date? = nil,
        now: Date = Date()
    ) {
        cancelRecurringReminders()
        guard enabled else { return }

        let calendar = Calendar.current
        let dates = Self.upcomingStartReminderDates(
            schedule: schedule,
            now: now,
            suppressUntil: suppressUntil,
            calendar: calendar
        )
        for (index, date) in dates.enumerated() {
            scheduleReminder(
                at: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                title: "Time to Start Fasting ⏱️",
                body: "Your fasting window starts now. Have a great fast!",
                identifier: Self.startReminderIdentifier(index: index),
                categoryIdentifier: NotificationManager.startFastCategoryId
            )
        }
    }

    private func scheduleReminder(
        at dateComponents: DateComponents,
        title: String,
        body: String,
        identifier: String,
        categoryIdentifier: String? = nil
    ) {

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Failed to schedule reminder \(identifier): \(error)")
            }
        }
    }

    public func cancelRecurringReminders() {
        // The weekly repeating `recurring_start_day_*` and `recurring_end_day_*` requests are no
        // longer scheduled, but earlier builds may still have them pending — keep cancelling them
        // or they fire forever.
        let legacyIdentifiers = (1...7).flatMap { [
            "recurring_start_day_\($0)",
            "recurring_end_day_\($0)"
        ] }
        let identifiers = legacyIdentifiers
            + (0...Self.startReminderHorizonDays).map { Self.startReminderIdentifier(index: $0) }
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

    /// Stage transitions, plus day milestones when `targetDuration` is given.
    public func scheduleStageTransitionNotifications(
        startDate: Date,
        targetDuration: TimeInterval? = nil,
        enabled: Bool = true,
        now: Date = Date()
    ) {
        cancelStageTransitionNotifications()
        guard enabled else { return }

        if let target = targetDuration {
            for milestone in Self.futureDayMilestones(startDate: startDate, targetDuration: target, now: now) {
                let content = UNMutableNotificationContent()
                content.title = "\(milestone.hours) Hours Fasted"
                content.body = "\(milestone.hoursRemaining) hours to go. Keep it up!"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: milestone.timeInterval, repeats: false)
                let identifier = Self.dayMilestoneIdentifier(forDay: milestone.hours / 24)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        NSLog("Failed to schedule day milestone \(identifier): \(error)")
                    }
                }
            }
        }

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

    /// Also cancels day milestones, which share the stage-change setting and lifetime.
    public func cancelStageTransitionNotifications() {
        let identifiers = MetabolicStage.allCases.map { Self.stageNotificationIdentifier(for: $0) }
            + (1...Self.maxDayMilestones).map { Self.dayMilestoneIdentifier(forDay: $0) }
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

// MARK: - Start Reminder and Day Milestone Timing

extension NotificationManager {
    /// How far ahead start reminders are scheduled. They are one-off requests rather than weekly
    /// repeats so that days covered by a fast can be skipped; every launch, foreground and fast
    /// change tops them back up.
    public static let startReminderHorizonDays = 14

    public static func startReminderIdentifier(index: Int) -> String {
        "start_reminder_\(index)"
    }

    /// Upcoming start-reminder times on the schedule's selected days, within the horizon, skipping
    /// any at or before `suppressUntil` (the active fast's goal) so a long fast isn't told to start.
    public static func upcomingStartReminderDates(
        schedule: NotificationSchedule,
        now: Date = Date(),
        suppressUntil: Date? = nil,
        calendar: Calendar = .current
    ) -> [Date] {
        let time = calendar.dateComponents([.hour, .minute], from: schedule.startReminderTime)
        let today = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(byAdding: .day, value: startReminderHorizonDays, to: now) else { return [] }

        return (0...startReminderHorizonDays).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  schedule.selectedDays.contains(calendar.component(.weekday, from: day)),
                  let fireDate = calendar.date(
                    bySettingHour: time.hour ?? 20,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: day
                  ),
                  fireDate > now, fireDate <= horizon else {
                return nil
            }
            if let suppressUntil = suppressUntil, fireDate <= suppressUntil {
                return nil
            }
            return fireDate
        }
    }

    /// Progress update at each full day of a multi-day fast, so the time between the last stage
    /// (24h) and the goal isn't silent.
    public struct DayMilestone: Equatable {
        public let hours: Int
        public let hoursRemaining: Int
        public let fireDate: Date
        public let timeInterval: TimeInterval

        public init(hours: Int, hoursRemaining: Int, fireDate: Date, timeInterval: TimeInterval) {
            self.hours = hours
            self.hoursRemaining = hoursRemaining
            self.fireDate = fireDate
            self.timeInterval = timeInterval
        }
    }

    /// Enough to cover the longest fast `FastingProtocol` will parse.
    static let maxDayMilestones = FastingProtocol.maxFixedLengthHours / 24

    public static func dayMilestoneIdentifier(forDay day: Int) -> String {
        "fast_day_\(day)"
    }

    /// Every whole day strictly before the goal, from day 2 on: day 1 coincides with the 24h stage
    /// notification.
    public static func futureDayMilestones(
        startDate: Date,
        targetDuration: TimeInterval,
        now: Date = Date()
    ) -> [DayMilestone] {
        guard maxDayMilestones >= 2 else { return [] }
        return (2...maxDayMilestones).compactMap { day -> DayMilestone? in
            let elapsed = TimeInterval(day * 24 * 3600)
            guard elapsed < targetDuration else { return nil }
            let fireDate = startDate.addingTimeInterval(elapsed)
            let interval = fireDate.timeIntervalSince(now)
            guard interval > 0 else { return nil }
            let remaining = Int(((targetDuration - elapsed) / 3600).rounded(.up))
            return DayMilestone(hours: day * 24, hoursRemaining: remaining, fireDate: fireDate, timeInterval: interval)
        }
    }
}
