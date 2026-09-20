import Foundation

extension FastingStateSnapshot {
    public func startingNow(
        startDate: Date = Date(),
        duration: TimeInterval,
        protocolType: String
    ) -> FastingStateSnapshot {
        FastingStateSnapshot(
            isFasting: true,
            startDate: startDate,
            targetDuration: duration,
            protocolType: protocolType,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCompletedFastDate: lastCompletedFastDate,
            updatedAt: Date()
        )
    }

    public func endingNow(at endDate: Date = Date(), calendar: Calendar = .current) -> FastingStateSnapshot {
        let isComplete = isGoalMet(at: endDate)
        // `StreakCalculator` counts distinct days, so a second completed fast on a day that already
        // counts adds nothing. Incrementing unconditionally showed an inflated streak until the app
        // next republished the authoritative value.
        let countsAsNewDay = isComplete && startsAnUncountedDay(calendar: calendar)
        let newStreak = countsAsNewDay ? currentStreak + 1 : currentStreak
        let newLongest = max(longestStreak, newStreak)
        return FastingStateSnapshot(
            isFasting: false,
            startDate: nil,
            targetDuration: nil,
            protocolType: protocolType,
            currentStreak: newStreak,
            longestStreak: newLongest,
            lastCompletedFastDate: endDate,
            lastCompletedFastStartDate: isComplete ? startDate : lastCompletedFastStartDate,
            updatedAt: Date()
        )
    }

    private func startsAnUncountedDay(calendar: Calendar) -> Bool {
        guard let start = startDate else { return false }
        // No prior completion recorded, or a payload from a build predating the field — assume the
        // day is new. Over-counting here is corrected on the next publish, same as before.
        guard let previous = lastCompletedFastStartDate else { return true }
        return !calendar.isDate(start, inSameDayAs: previous)
    }

    public func snoozed(by extensionSeconds: TimeInterval) -> FastingStateSnapshot {
        guard isFasting, let currentTarget = targetDuration else { return self }
        return FastingStateSnapshot(
            isFasting: true,
            startDate: startDate,
            targetDuration: currentTarget + extensionSeconds,
            protocolType: protocolType,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCompletedFastDate: lastCompletedFastDate,
            updatedAt: Date()
        )
    }
}

public struct FastCommandFactory {
    public static func shouldDirectlyEnd(snapshot: FastingStateSnapshot, at date: Date = Date()) -> Bool {
        snapshot.isGoalMet(at: date)
    }
}
