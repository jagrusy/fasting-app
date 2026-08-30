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
    public static func entries(
        for snapshot: FastingStateSnapshot,
        now: Date = Date()
    ) -> [FastWidgetEntry] {
        guard snapshot.isFasting, let start = snapshot.startDate else {
            return [FastWidgetEntry(date: now, snapshot: snapshot)]
        }

        var transitionDates: Set<Date> = [now]

        // Add future metabolic stage boundaries
        for stage in MetabolicStage.allCases {
            let stageDate = start.addingTimeInterval(stage.startSeconds)
            if stageDate > now {
                transitionDates.insert(stageDate)
            }
        }

        // Add goal date if in future
        if let target = snapshot.targetDuration, target > 0 {
            let goalDate = start.addingTimeInterval(target)
            if goalDate > now {
                transitionDates.insert(goalDate)
            }
        }

        let sortedDates = transitionDates.sorted()
        return sortedDates.map { date in
            FastWidgetEntry(date: date, snapshot: snapshot)
        }
    }

    public static func nextReloadDate(
        entries: [FastWidgetEntry],
        now: Date = Date()
    ) -> Date? {
        entries.first(where: { $0.date > now })?.date
    }
}
