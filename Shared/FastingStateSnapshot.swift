import Foundation

public struct FastingStateSnapshot: Codable, Sendable, Equatable {
    public var isFasting: Bool
    public var startDate: Date?
    public var targetDuration: TimeInterval?
    public var protocolType: String?
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastCompletedFastDate: Date?
    /// Start date of the most recent completed fast. `StreakCalculator` keys streak days off when a
    /// fast *started*, so this is what an optimistic streak bump has to compare against;
    /// `lastCompletedFastDate` holds an end date and can land on a different calendar day.
    /// Absent from payloads written by older builds, hence optional.
    public var lastCompletedFastStartDate: Date?
    public var updatedAt: Date

    public init(
        isFasting: Bool,
        startDate: Date? = nil,
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedFastDate: Date? = nil,
        lastCompletedFastStartDate: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.isFasting = isFasting
        self.startDate = startDate
        self.targetDuration = targetDuration
        self.protocolType = protocolType
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedFastDate = lastCompletedFastDate
        self.lastCompletedFastStartDate = lastCompletedFastStartDate
        self.updatedAt = updatedAt
    }

    public static var idle: FastingStateSnapshot {
        FastingStateSnapshot(
            isFasting: false,
            startDate: nil,
            targetDuration: nil,
            protocolType: nil,
            currentStreak: 0,
            longestStreak: 0,
            lastCompletedFastDate: nil,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    public func elapsedSeconds(at date: Date = Date()) -> TimeInterval {
        guard isFasting, let start = startDate else { return 0 }
        return max(0, date.timeIntervalSince(start))
    }

    public func remainingSeconds(at date: Date = Date()) -> TimeInterval? {
        guard isFasting, let target = targetDuration else { return nil }
        let elapsed = elapsedSeconds(at: date)
        return max(0, target - elapsed)
    }

    public func progress(at date: Date = Date()) -> Double {
        guard isFasting, let target = targetDuration, target > 0 else { return 0.0 }
        return elapsedSeconds(at: date) / target
    }

    /// `progress(at:)` intentionally runs past 1.0 so callers can detect an overdue fast. Gauges
    /// need the bounded value.
    public func clampedProgress(at date: Date = Date()) -> Double {
        min(1.0, max(0.0, progress(at: date)))
    }

    /// Progress through the *current* metabolic stage, 0...1. Nil when not fasting; 1.0 once in the
    /// terminal stage, which has no upper boundary to travel toward.
    public func stageProgress(at date: Date = Date()) -> Double? {
        guard isFasting, let stage = currentStage(at: date) else { return nil }
        guard let next = MetabolicStage(rawValue: stage.rawValue + 1) else { return 1.0 }
        let span = next.startSeconds - stage.startSeconds
        guard span > 0 else { return 1.0 }
        let into = elapsedSeconds(at: date) - stage.startSeconds
        return min(1.0, max(0.0, into / span))
    }

    /// When the current eating window closes, derived from the protocol's eating hours. Nil while
    /// fasting, or before any fast has been completed.
    public func eatingWindowEnd() -> Date? {
        guard !isFasting, let last = lastCompletedFastDate else { return nil }
        let proto = fastingProtocol ?? .default
        return last.addingTimeInterval(proto.eatingSeconds)
    }

    /// How much of the eating window has elapsed, 0...1. Nil when fasting or when no window is open.
    public func eatingWindowProgress(at date: Date = Date()) -> Double? {
        guard let end = eatingWindowEnd(), let start = lastCompletedFastDate else { return nil }
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return nil }
        return min(1.0, max(0.0, date.timeIntervalSince(start) / span))
    }

    public func isGoalMet(at date: Date = Date()) -> Bool {
        guard isFasting, let target = targetDuration, target > 0 else { return false }
        return elapsedSeconds(at: date) >= target
    }

    public func currentStage(at date: Date = Date()) -> MetabolicStage? {
        guard isFasting else { return nil }
        return MetabolicStage.stage(for: elapsedSeconds(at: date))
    }

    public func nextStageBoundary(at date: Date = Date()) -> (stage: MetabolicStage, date: Date)? {
        guard isFasting, let start = startDate else { return nil }
        for stage in MetabolicStage.allCases {
            let stageDate = start.addingTimeInterval(stage.startSeconds)
            if stageDate > date {
                return (stage, stageDate)
            }
        }
        return nil
    }

    public var fastingProtocol: FastingProtocol? {
        guard let proto = protocolType else { return nil }
        return FastingProtocol.from(protocolType: proto)
    }
}
