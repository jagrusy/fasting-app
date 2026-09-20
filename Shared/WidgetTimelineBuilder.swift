import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct FastWidgetEntry: Equatable, Sendable {
    public let date: Date
    public let snapshot: FastingStateSnapshot

    public init(date: Date, snapshot: FastingStateSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct WidgetTimelineBuilder {
    /// How far ahead a single timeline reaches before WidgetKit is asked for a new one.
    ///
    /// Entries *inside* one timeline are pre-rendered and cost nothing — the extension is not woken
    /// to display them. Only the reload spends the system's daily refresh budget, so the horizon is
    /// what needs to stay coarse, not the entry spacing.
    public static let refreshHorizon: TimeInterval = 4 * 3600

    static let minStep: TimeInterval = 5 * 60
    static let maxStep: TimeInterval = 30 * 60

    public static func entries(
        for snapshot: FastingStateSnapshot,
        now: Date = Date()
    ) -> [FastWidgetEntry] {
        guard snapshot.isFasting, let start = snapshot.startDate else {
            return [FastWidgetEntry(date: now, snapshot: snapshot)]
        }

        let horizon = now.addingTimeInterval(refreshHorizon)
        var transitionDates: Set<Date> = [now]

        // `Gauge` has no `timerInterval` initializer the way `Text` and `ProgressView` do, so it
        // renders one frozen value per entry. Stepping finely enough that the arc advances about a
        // percent at a time is what keeps it from visibly sticking between stage boundaries.
        let step = gaugeStep(for: snapshot.targetDuration)
        var cursor = now.addingTimeInterval(step)
        while cursor <= horizon {
            transitionDates.insert(cursor)
            cursor = cursor.addingTimeInterval(step)
        }

        for stage in MetabolicStage.allCases {
            let stageDate = start.addingTimeInterval(stage.startSeconds)
            if stageDate > now && stageDate <= horizon {
                transitionDates.insert(stageDate)
            }
        }

        if let target = snapshot.targetDuration, target > 0 {
            let goalDate = start.addingTimeInterval(target)
            if goalDate > now && goalDate <= horizon {
                transitionDates.insert(goalDate)
            }
        }

        return transitionDates.sorted().map { date in
            FastWidgetEntry(date: date, snapshot: snapshot)
        }
    }

    /// Entry spacing that moves a goal gauge roughly one percent at a time, bounded so a very short
    /// fast doesn't generate entries by the hundred and a very long one still feels live.
    static func gaugeStep(for targetDuration: TimeInterval?) -> TimeInterval {
        guard let target = targetDuration, target > 0 else { return maxStep }
        return min(maxStep, max(minStep, target / 100))
    }

    /// Always a real date — never "no reload".
    ///
    /// Returning nil here used to leave the provider with `.never`, which strands a widget whose
    /// transitions have all passed. `reloadAllTimelines()` only rescues it from the *iOS app*
    /// process, so a fast ended on the Watch while the phone app was suspended would keep showing
    /// as active indefinitely.
    public static func nextReloadDate(
        entries: [FastWidgetEntry],
        now: Date = Date()
    ) -> Date {
        let horizon = now.addingTimeInterval(refreshHorizon)
        guard let last = entries.map(\.date).max(), last > now else { return horizon }
        return min(last, horizon)
    }
}
