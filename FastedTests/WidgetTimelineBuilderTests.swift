import XCTest
@testable import Fasted

final class WidgetTimelineBuilderTests: XCTestCase {
    private let horizon = WidgetTimelineBuilder.refreshHorizon

    private func activeSnapshot(
        start: Date,
        target: TimeInterval = 16 * 3600
    ) -> FastingStateSnapshot {
        FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: target,
            protocolType: "16:8"
        )
    }

    func testIdleSnapshotTimeline() {
        let now = Date(timeIntervalSince1970: 1700000000)
        let entries = WidgetTimelineBuilder.entries(for: .idle, now: now)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.date, now)
        XCTAssertFalse(entries.first?.snapshot.isFasting ?? true)
    }

    /// Regression: an idle timeline used to yield a nil reload date, which the providers turned into
    /// `.never`. A fast started on the Watch would then never reach the iOS widget.
    func testIdleSnapshotStillSchedulesAReload() {
        let now = Date(timeIntervalSince1970: 1700000000)
        let entries = WidgetTimelineBuilder.entries(for: .idle, now: now)

        let reload = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now)
        XCTAssertEqual(reload, now.addingTimeInterval(horizon))
        XCTAssertGreaterThan(reload, now)
    }

    /// Regression: a fast past every stage boundary and its goal used to produce a single entry and
    /// a `.never` policy, stranding the widget on stale state indefinitely.
    func testLongOverdueFastStillSchedulesAReload() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(30 * 3600)
        let entries = WidgetTimelineBuilder.entries(for: activeSnapshot(start: start), now: now)

        let reload = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now)
        XCTAssertGreaterThan(reload, now)
        XCTAssertLessThanOrEqual(reload, now.addingTimeInterval(horizon))
    }

    /// A `Gauge` renders a fixed value per entry, so the spacing between entries is the gauge's
    /// effective frame rate.
    func testEntriesAreDenseEnoughForAGaugeToAdvance() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(3 * 3600)
        let entries = WidgetTimelineBuilder.entries(for: activeSnapshot(start: start), now: now)

        XCTAssertEqual(entries.first?.date, now)
        XCTAssertGreaterThan(entries.count, 20)

        let dates = entries.map(\.date)
        for (earlier, later) in zip(dates, dates.dropFirst()) {
            XCTAssertLessThanOrEqual(
                later.timeIntervalSince(earlier),
                WidgetTimelineBuilder.maxStep,
                "Gauge would visibly stall between \(earlier) and \(later)"
            )
        }
    }

    func testEntriesStayWithinTheRefreshHorizon() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(3 * 3600)
        let entries = WidgetTimelineBuilder.entries(for: activeSnapshot(start: start), now: now)

        for entry in entries {
            XCTAssertGreaterThanOrEqual(entry.date, now)
            XCTAssertLessThanOrEqual(entry.date, now.addingTimeInterval(horizon))
        }
    }

    func testStageAndGoalBoundariesWithinHorizonArePresent() {
        let start = Date(timeIntervalSince1970: 1700000000)
        // 3h in: the 4h glycogen boundary falls an hour out, inside the horizon.
        let now = start.addingTimeInterval(3 * 3600)
        let entries = WidgetTimelineBuilder.entries(for: activeSnapshot(start: start), now: now)
        let dates = Set(entries.map(\.date))

        XCTAssertTrue(dates.contains(start.addingTimeInterval(4 * 3600)))
        // The 16h goal and the 12h boundary are far beyond the horizon and must not be emitted.
        XCTAssertFalse(dates.contains(start.addingTimeInterval(12 * 3600)))
        XCTAssertFalse(dates.contains(start.addingTimeInterval(16 * 3600)))
    }

    func testGoalBoundaryIsPresentWhenItFallsInsideTheHorizon() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(14 * 3600)
        let entries = WidgetTimelineBuilder.entries(for: activeSnapshot(start: start), now: now)

        XCTAssertTrue(Set(entries.map(\.date)).contains(start.addingTimeInterval(16 * 3600)))
    }

    /// Regression: the reload used to be scheduled at the *first* future entry, which made every
    /// later entry in the timeline dead weight and burned a refresh at each stage boundary.
    func testReloadIsScheduledAtTheEndOfTheTimelineNotTheStart() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(3 * 3600)
        let entries = WidgetTimelineBuilder.entries(for: activeSnapshot(start: start), now: now)

        let reload = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now)
        let lastEntry = entries.map(\.date).max()
        XCTAssertEqual(reload, lastEntry)
        XCTAssertGreaterThan(reload, entries[1].date)
    }

    func testGaugeStepIsBoundedForExtremeGoals() {
        XCTAssertEqual(WidgetTimelineBuilder.gaugeStep(for: 30 * 60), WidgetTimelineBuilder.minStep)
        XCTAssertEqual(WidgetTimelineBuilder.gaugeStep(for: 100 * 3600), WidgetTimelineBuilder.maxStep)
        XCTAssertEqual(WidgetTimelineBuilder.gaugeStep(for: nil), WidgetTimelineBuilder.maxStep)
        XCTAssertEqual(WidgetTimelineBuilder.gaugeStep(for: 0), WidgetTimelineBuilder.maxStep)
        XCTAssertEqual(WidgetTimelineBuilder.gaugeStep(for: 16 * 3600), 576)
    }
}
