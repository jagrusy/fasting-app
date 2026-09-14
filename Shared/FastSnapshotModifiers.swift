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

    public func endingNow(at endDate: Date = Date()) -> FastingStateSnapshot {
        let isComplete = isGoalMet(at: endDate)
        let newStreak = isComplete ? currentStreak + 1 : currentStreak
        let newLongest = max(longestStreak, newStreak)
        return FastingStateSnapshot(
            isFasting: false,
            startDate: nil,
            targetDuration: nil,
            protocolType: protocolType,
            currentStreak: newStreak,
            longestStreak: newLongest,
            lastCompletedFastDate: endDate,
            updatedAt: Date()
        )
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
