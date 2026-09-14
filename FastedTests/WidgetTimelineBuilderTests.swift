import XCTest
@testable import Fasted

final class WidgetTimelineBuilderTests: XCTestCase {
    func testIdleSnapshotTimeline() {
        let now = Date(timeIntervalSince1970: 1700000000)
        let entries = WidgetTimelineBuilder.entries(for: .idle, now: now)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.date, now)
        XCTAssertFalse(entries.first?.snapshot.isFasting ?? true)

        let nextReload = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now)
        XCTAssertNil(nextReload)
    }

    func testActiveFastThreeHoursIn() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(3 * 3600) // 3 hours in

        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8"
        )

        let entries = WidgetTimelineBuilder.entries(for: snapshot, now: now)

        // Expected future dates:
        // - now (3h)
        // - glycogenDepletion (4h = start + 4h)
        // - fatBurning (12h = start + 12h)
        // - goalDate (16h = start + 16h)
        // - autophagy (18h = start + 18h)
        // - deepKetosis (24h = start + 24h)
        XCTAssertEqual(entries.count, 6)

        XCTAssertEqual(entries[0].date, now)
        XCTAssertEqual(entries[1].date, start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(entries[2].date, start.addingTimeInterval(12 * 3600))
        XCTAssertEqual(entries[3].date, start.addingTimeInterval(16 * 3600))
        XCTAssertEqual(entries[4].date, start.addingTimeInterval(18 * 3600))
        XCTAssertEqual(entries[5].date, start.addingTimeInterval(24 * 3600))

        // No past dated entries (0h bloodSugarReset is before 3h, so not included)
        for entry in entries {
            XCTAssertGreaterThanOrEqual(entry.date, now)
        }

        let nextReload = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now)
        XCTAssertEqual(nextReload, start.addingTimeInterval(4 * 3600))
    }

    func testGoalPassedFast() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let now = start.addingTimeInterval(17 * 3600) // 17 hours in (16h goal already met)

        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8"
        )

        let entries = WidgetTimelineBuilder.entries(for: snapshot, now: now)

        // Expected future dates:
        // - now (17h)
        // - autophagy (18h = start + 18h)
        // - deepKetosis (24h = start + 24h)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].date, now)
        XCTAssertEqual(entries[1].date, start.addingTimeInterval(18 * 3600))
        XCTAssertEqual(entries[2].date, start.addingTimeInterval(24 * 3600))
    }
}
