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

// MARK: - Start Reminders and Day Milestone Timing

extension NotificationManager {
    public func scheduleRecurringReminders(
        schedule: NotificationSchedule,
        enabled: Bool,
        suppressUntil: Date? = nil,
        now: Date = Date()
    ) {
        cancelRecurringReminders()
        guard enabled else { return }

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: schedule.startReminderTime)
        let plan = Self.startReminderPlan(
            schedule: schedule,
            now: now,
            suppressUntil: suppressUntil,
            calendar: calendar
        )
        for reminder in plan {
            if reminder.deferredDates.isEmpty {
                scheduleStartReminder(
                    at: DateComponents(hour: time.hour ?? 20, minute: time.minute ?? 0, weekday: reminder.weekday),
                    repeats: true,
                    identifier: Self.startReminderIdentifier(weekday: reminder.weekday, week: 0)
                )
            }
            for (week, date) in reminder.deferredDates.enumerated() {
                scheduleStartReminder(
                    at: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                    repeats: false,
                    identifier: Self.startReminderIdentifier(weekday: reminder.weekday, week: week)
                )
            }
        }
    }

    private func scheduleStartReminder(at dateComponents: DateComponents, repeats: Bool, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Start Fasting ⏱️"
        content.body = "Your fasting window starts now. Have a great fast!"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.startFastCategoryId

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
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
        let identifiers = (1...7).flatMap { weekday in
            ["recurring_end_day_\(weekday)"]
                + (0..<Self.deferredReminderWeeks).map { Self.startReminderIdentifier(weekday: weekday, week: $0) }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// How many weekly occurrences a deferred weekday is scheduled for, one-off, after the active
    /// fast's goal. iOS can't start a repeating trigger at a future date, so this bounds how long
    /// that weekday keeps reminding if the app is never opened again after the fast; any sync
    /// (launch, foreground, fast change, acting on a reminder) restores the weekly repeat.
    public static let deferredReminderWeeks = 4

    /// Week 0 keeps the identifier earlier builds used for the weekly repeat, so an upgrade replaces
    /// rather than duplicates it.
    public static func startReminderIdentifier(weekday: Int, week: Int) -> String {
        week == 0 ? "recurring_start_day_\(weekday)" : "recurring_start_day_\(weekday)_\(week)"
    }

    /// One start reminder per selected weekday.
    public struct StartReminder: Equatable {
        public let weekday: Int
        /// Empty for the normal weekly repeat. Set when that weekday's next reminder falls inside
        /// the active fast: the next `deferredReminderWeeks` occurrences after the fast's goal.
        public let deferredDates: [Date]

        public init(weekday: Int, deferredDates: [Date] = []) {
            self.weekday = weekday
            self.deferredDates = deferredDates
        }
    }

    /// Weekly repeats stay scheduled even if the app isn't opened; only a weekday whose next
    /// reminder would land during the active fast (before `suppressUntil`, its goal) is moved.
    public static func startReminderPlan(
        schedule: NotificationSchedule,
        now: Date = Date(),
        suppressUntil: Date? = nil,
        calendar: Calendar = .current
    ) -> [StartReminder] {
        let time = calendar.dateComponents([.hour, .minute], from: schedule.startReminderTime)
        return schedule.selectedDays.sorted().map { weekday -> StartReminder in
            guard let suppressUntil = suppressUntil, suppressUntil > now else {
                return StartReminder(weekday: weekday)
            }
            let matching = DateComponents(hour: time.hour ?? 20, minute: time.minute ?? 0, weekday: weekday)
            guard let next = calendar.nextDate(after: now, matching: matching, matchingPolicy: .nextTime),
                  next <= suppressUntil,
                  let afterFast = calendar.nextDate(after: suppressUntil, matching: matching, matchingPolicy: .nextTime)
            else {
                return StartReminder(weekday: weekday)
            }
            let deferred = (0..<deferredReminderWeeks).compactMap {
                calendar.date(byAdding: .weekOfYear, value: $0, to: afterFast)
            }
            return StartReminder(weekday: weekday, deferredDates: deferred)
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
