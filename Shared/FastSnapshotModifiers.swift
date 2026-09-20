import Foundation
import SwiftUI

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

/// Three-way state behind the Control Center tile, replacing a plain on/off toggle.
///
/// A toggle implies a symmetric, reversible action, but ending a fast early isn't reversible the
/// way starting one is — it writes a partial fast to history and breaks the streak, and a control
/// can't show a confirmation dialog. `.active` therefore opens the app instead of ending anything;
/// only `.complete`, where `shouldDirectlyEnd` already says an end is safe, acts directly.
public enum FastControlState: String, Sendable, Equatable {
    case idle
    case active
    case complete

    public static func from(snapshot: FastingStateSnapshot, at date: Date = Date()) -> FastControlState {
        guard snapshot.isFasting else { return .idle }
        return FastCommandFactory.shouldDirectlyEnd(snapshot: snapshot, at: date) ? .complete : .active
    }

    public var label: String {
        switch self {
        case .idle: return "Start Fast"
        case .active: return "Fasting"
        case .complete: return "Fasting Complete"
        }
    }

    public var systemImage: String {
        switch self {
        case .idle: return "timer"
        case .active: return "flame.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .idle, .active: return SolsticeColors.solarAmber
        case .complete: return SolsticeColors.emeraldGlow
        }
    }
}
