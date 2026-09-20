import XCTest
@testable import Fasted

/// `endingNow` produces the streak a widget shows between the tap and the app republishing the
/// authoritative value, so it has to agree with `StreakCalculator`, which counts *distinct days*
/// keyed on when each fast started.
final class OptimisticStreakTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func fasting(start: Date, lastCompletedStart: Date?) -> FastingStateSnapshot {
        FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 4 * 3600,
            protocolType: "16:8",
            currentStreak: 3,
            longestStreak: 5,
            lastCompletedFastDate: lastCompletedStart,
            lastCompletedFastStartDate: lastCompletedStart
        )
    }

    /// Regression: this used to increment unconditionally, so a second completed fast on a day the
    /// streak already counted flashed 4 when the real value stayed 3.
    func testSecondCompletedFastOnTheSameDayDoesNotBumpTheStreak() {
        let snapshot = fasting(start: day(10, hour: 14), lastCompletedStart: day(10, hour: 2))
        let ended = snapshot.endingNow(at: day(10, hour: 20), calendar: calendar)

        XCTAssertEqual(ended.currentStreak, 3)
        XCTAssertEqual(ended.longestStreak, 5)
    }

    func testCompletedFastOnANewDayBumpsTheStreak() {
        let snapshot = fasting(start: day(11, hour: 2), lastCompletedStart: day(10, hour: 2))
        let ended = snapshot.endingNow(at: day(11, hour: 8), calendar: calendar)

        XCTAssertEqual(ended.currentStreak, 4)
    }

    func testFirstEverCompletedFastBumpsTheStreak() {
        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: day(10, hour: 2),
            targetDuration: 4 * 3600,
            protocolType: "16:8",
            currentStreak: 0,
            longestStreak: 0
        )
        let ended = snapshot.endingNow(at: day(10, hour: 8), calendar: calendar)

        XCTAssertEqual(ended.currentStreak, 1)
        XCTAssertEqual(ended.longestStreak, 1)
    }

    func testEndingShortOfTheGoalNeverBumpsTheStreak() {
        let snapshot = fasting(start: day(11, hour: 2), lastCompletedStart: day(10, hour: 2))
        let ended = snapshot.endingNow(at: day(11, hour: 3), calendar: calendar)

        XCTAssertEqual(ended.currentStreak, 3)
    }

    func testCompletingRecordsTheStartDayForTheNextComparison() {
        let start = day(11, hour: 2)
        let snapshot = fasting(start: start, lastCompletedStart: day(10, hour: 2))
        let ended = snapshot.endingNow(at: day(11, hour: 8), calendar: calendar)

        XCTAssertEqual(ended.lastCompletedFastStartDate, start)
    }

    func testEndingShortOfTheGoalLeavesTheRecordedStartDayAlone() {
        let previous = day(10, hour: 2)
        let snapshot = fasting(start: day(11, hour: 2), lastCompletedStart: previous)
        let ended = snapshot.endingNow(at: day(11, hour: 3), calendar: calendar)

        XCTAssertEqual(ended.lastCompletedFastStartDate, previous)
    }

    /// Payloads written before the field existed decode it as nil; the old optimistic behaviour is
    /// the safe fallback there.
    func testMissingStartDayFallsBackToBumping() {
        let snapshot = fasting(start: day(11, hour: 2), lastCompletedStart: nil)
        let ended = snapshot.endingNow(at: day(11, hour: 8), calendar: calendar)

        XCTAssertEqual(ended.currentStreak, 4)
    }
}
