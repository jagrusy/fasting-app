import Foundation
import UserNotifications

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

        delivery.add(request) { error in
            if let error = error {
                NSLog("Failed to schedule reminder \(identifier): \(error)")
            }
        }
    }

    public func cancelRecurringReminders() {
        // `recurring_end_day_*` is no longer scheduled, but builds shipped before it was removed
        // may still have those requests pending — keep cancelling them or they fire forever.
        delivery.remove(FastingReminderIDs.allRecurringIdentifiers)
    }

    /// How many weekly occurrences a deferred weekday is scheduled for, one-off, after the active
    /// fast's goal. iOS can't start a repeating trigger at a future date, so this bounds how long
    /// that weekday keeps reminding if the app is never opened again after the fast; any sync
    /// (launch, foreground, fast change, acting on a reminder) restores the weekly repeat.
    public static let deferredReminderWeeks = FastingReminderIDs.deferredReminderWeeks

    /// Week 0 keeps the identifier earlier builds used for the weekly repeat, so an upgrade replaces
    /// rather than duplicates it.
    public static func startReminderIdentifier(weekday: Int, week: Int) -> String {
        FastingReminderIDs.startReminderIdentifier(weekday: weekday, week: week)
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
