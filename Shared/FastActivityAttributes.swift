import Foundation
#if canImport(ActivityKit) && !os(watchOS)
import ActivityKit

public struct FastActivityAttributes: ActivityAttributes {
    /// Everything the Live Activity renders. `Text(timerInterval:)` keeps the clock ticking without
    /// an update, but gauges are static per content state, so the progress values here are refreshed
    /// whenever the app republishes its snapshot.
    public struct ContentState: Codable, Hashable {
        public var startDate: Date
        public var goalDate: Date
        public var progress: Double
        public var stageRawValue: Int
        public var stageProgress: Double
        public var isGoalMet: Bool
        public var currentStreak: Int

        public init(
            startDate: Date,
            goalDate: Date,
            progress: Double,
            stageRawValue: Int,
            stageProgress: Double,
            isGoalMet: Bool,
            currentStreak: Int
        ) {
            self.startDate = startDate
            self.goalDate = goalDate
            self.progress = progress
            self.stageRawValue = stageRawValue
            self.stageProgress = stageProgress
            self.isGoalMet = isGoalMet
            self.currentStreak = currentStreak
        }

        public var stage: MetabolicStage? {
            MetabolicStage(rawValue: stageRawValue)
        }
    }

    public var protocolType: String

    public init(protocolType: String) {
        self.protocolType = protocolType
    }
}

extension FastActivityAttributes.ContentState {
    /// Nil when the snapshot has no active fast to describe.
    public init?(snapshot: FastingStateSnapshot, at date: Date = Date()) {
        guard snapshot.isFasting,
              let start = snapshot.startDate,
              let target = snapshot.targetDuration, target > 0 else { return nil }

        self.init(
            startDate: start,
            goalDate: start.addingTimeInterval(target),
            progress: snapshot.clampedProgress(at: date),
            stageRawValue: (snapshot.currentStage(at: date) ?? .bloodSugarReset).rawValue,
            stageProgress: snapshot.stageProgress(at: date) ?? 0,
            isGoalMet: snapshot.isGoalMet(at: date),
            currentStreak: snapshot.currentStreak
        )
    }
}
#endif
