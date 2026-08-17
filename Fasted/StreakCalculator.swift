import Foundation

public enum DayFastStatus: Equatable {
    case none
    case partial(hours: Double)
    case goalMet(hours: Double)
}

public struct StreakInfo: Equatable {
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalCompletedFasts: Int
    public let totalFastingSeconds: TimeInterval

    public init(
        currentStreak: Int,
        bestStreak: Int,
        totalCompletedFasts: Int,
        totalFastingSeconds: TimeInterval
    ) {
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.totalCompletedFasts = totalCompletedFasts
        self.totalFastingSeconds = totalFastingSeconds
    }
}

public struct StreakCalculator {
    public static func calculate(
        from fasts: [Fast],
        calendar: Calendar = .current,
        relativeTo now: Date = Date()
    ) -> StreakInfo {
        let completedFasts = fasts.filter { fast in
            guard let start = fast.startDate, let end = fast.endDate else { return false }
            let duration = end.timeIntervalSince(start)
            return fast.isCompleted || (duration >= fast.targetDuration)
        }

        let totalSeconds = fasts.reduce(0.0) { acc, fast in
            guard let start = fast.startDate, let end = fast.endDate else { return acc }
            return acc + max(0, end.timeIntervalSince(start))
        }

        let completedDaysSet = Set(completedFasts.compactMap { fast -> Date? in
            guard let start = fast.startDate else { return nil }
            return calendar.startOfDay(for: start)
        })

        let currentStreak = computeCurrentStreak(days: completedDaysSet, calendar: calendar, now: now)
        let bestStreak = computeBestStreak(days: completedDaysSet, calendar: calendar)

        return StreakInfo(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalCompletedFasts: completedFasts.count,
            totalFastingSeconds: totalSeconds
        )
    }

    private static func computeCurrentStreak(days: Set<Date>, calendar: Calendar, now: Date) -> Int {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var checkDate: Date?
        if days.contains(today) {
            checkDate = today
        } else if days.contains(yesterday) {
            checkDate = yesterday
        }

        guard let startCheck = checkDate else { return 0 }

        var streak = 0
        var cursor = startCheck
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private static func computeBestStreak(days: Set<Date>, calendar: Calendar) -> Int {
        let ascendingDays = days.sorted(by: <)
        var bestStreak = 0
        var runningStreak = 0
        var previousDay: Date?

        for day in ascendingDays {
            if let prev = previousDay {
                if let nextExpected = calendar.date(byAdding: .day, value: 1, to: prev),
                   calendar.isDate(day, inSameDayAs: nextExpected) {
                    runningStreak += 1
                } else {
                    runningStreak = 1
                }
            } else {
                runningStreak = 1
            }
            previousDay = day
            bestStreak = max(bestStreak, runningStreak)
        }
        return bestStreak
    }

    public static func fastStatus(for date: Date, in fasts: [Fast], calendar: Calendar = .current) -> DayFastStatus {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return .none }

        let dayFasts = fasts.filter { fast in
            guard let start = fast.startDate else { return false }
            return start >= startOfDay && start < endOfDay
        }

        guard !dayFasts.isEmpty else { return .none }

        var totalSeconds: Double = 0
        var hasGoalMet = false

        for fast in dayFasts {
            let start = fast.startDate ?? Date()
            let end = fast.endDate ?? start
            let duration = max(0, end.timeIntervalSince(start))
            totalSeconds += duration
            if fast.isCompleted || duration >= fast.targetDuration {
                hasGoalMet = true
            }
        }

        let totalHours = totalSeconds / 3600.0
        return hasGoalMet ? .goalMet(hours: totalHours) : .partial(hours: totalHours)
    }
}
