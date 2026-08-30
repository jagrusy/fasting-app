import Foundation

public struct FastingStateSnapshot: Codable, Sendable, Equatable {
    public var isFasting: Bool
    public var startDate: Date?
    public var targetDuration: TimeInterval?
    public var protocolType: String?
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastCompletedFastDate: Date?
    public var updatedAt: Date

    public init(
        isFasting: Bool,
        startDate: Date? = nil,
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedFastDate: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.isFasting = isFasting
        self.startDate = startDate
        self.targetDuration = targetDuration
        self.protocolType = protocolType
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedFastDate = lastCompletedFastDate
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
