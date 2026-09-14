import XCTest
@testable import Fasted

final class AppIntentsTests: XCTestCase {
    func testStartingNowModifier() {
        let idle = FastingStateSnapshot.idle
        let start = Date(timeIntervalSince1970: 1700000000)
        let updated = idle.startingNow(startDate: start, duration: 16 * 3600, protocolType: "16:8")

        XCTAssertTrue(updated.isFasting)
        XCTAssertEqual(updated.startDate, start)
        XCTAssertEqual(updated.targetDuration, 16 * 3600)
        XCTAssertEqual(updated.protocolType, "16:8")
        XCTAssertEqual(updated.currentStreak, 0)
    }

    func testEndingNowModifierWhenGoalMet() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let active = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8",
            currentStreak: 2,
            longestStreak: 5
        )

        // End after 17 hours (goal met)
        let end = start.addingTimeInterval(17 * 3600)
        let ended = active.endingNow(at: end)

        XCTAssertFalse(ended.isFasting)
        XCTAssertNil(ended.startDate)
        XCTAssertEqual(ended.currentStreak, 3)
        XCTAssertEqual(ended.longestStreak, 5)
        XCTAssertEqual(ended.lastCompletedFastDate, end)
    }

    func testEndingNowModifierWhenGoalNotMet() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let active = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8",
            currentStreak: 2,
            longestStreak: 5
        )

        // End after 10 hours (early end, goal not met)
        let end = start.addingTimeInterval(10 * 3600)
        let ended = active.endingNow(at: end)

        XCTAssertFalse(ended.isFasting)
        XCTAssertNil(ended.startDate)
        // Streak is not incremented
        XCTAssertEqual(ended.currentStreak, 2)
        XCTAssertEqual(ended.longestStreak, 5)
        XCTAssertEqual(ended.lastCompletedFastDate, end)
    }

    func testSnoozedModifier() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let active = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8"
        )

        let snoozed = active.snoozed(by: 3600)
        XCTAssertTrue(snoozed.isFasting)
        XCTAssertEqual(snoozed.targetDuration, 17 * 3600)
        XCTAssertEqual(snoozed.startDate, start)
    }

    func testFastCommandFactoryShouldDirectlyEnd() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let active = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8"
        )

        // At 10 hours, goal not met
        XCTAssertFalse(FastCommandFactory.shouldDirectlyEnd(snapshot: active, at: start.addingTimeInterval(10 * 3600)))

        // At 16 hours, goal met
        XCTAssertTrue(FastCommandFactory.shouldDirectlyEnd(snapshot: active, at: start.addingTimeInterval(16 * 3600)))

        // At 20 hours, goal met
        XCTAssertTrue(FastCommandFactory.shouldDirectlyEnd(snapshot: active, at: start.addingTimeInterval(20 * 3600)))
    }
}
