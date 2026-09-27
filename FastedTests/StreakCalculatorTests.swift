import XCTest
import CoreData
@testable import Fasted

@MainActor
final class StreakCalculatorTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        self.persistenceController = controller
        self.context = controller.container.viewContext
    }

    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        try super.tearDownWithError()
    }

    func testStreakCalculatorWithConsecutiveDays() throws {
        let ctx = try XCTUnwrap(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var testFasts: [Fast] = []
        for dayOffset in 0..<4 {
            let fast = Fast(context: ctx)
            fast.id = UUID()
            let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            fast.startDate = dayDate
            fast.endDate = dayDate.addingTimeInterval(16 * 3600)
            fast.targetDuration = 16 * 3600
            fast.isCompleted = true
            testFasts.append(fast)
        }

        let streakInfo = StreakCalculator.calculate(from: testFasts, calendar: calendar, relativeTo: Date())
        XCTAssertEqual(streakInfo.currentStreak, 4)
        XCTAssertEqual(streakInfo.bestStreak, 4)
        XCTAssertEqual(streakInfo.totalCompletedFasts, 4)
    }

    func testStreakCalculatorWithBrokenStreak() throws {
        let ctx = try XCTUnwrap(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var testFasts: [Fast] = []
        for dayOffset in [5, 6, 7] {
            let fast = Fast(context: ctx)
            fast.id = UUID()
            let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            fast.startDate = dayDate
            fast.endDate = dayDate.addingTimeInterval(16 * 3600)
            fast.targetDuration = 16 * 3600
            fast.isCompleted = true
            testFasts.append(fast)
        }

        let todayFast = Fast(context: ctx)
        todayFast.id = UUID()
        todayFast.startDate = today
        todayFast.endDate = today.addingTimeInterval(16 * 3600)
        todayFast.targetDuration = 16 * 3600
        todayFast.isCompleted = true
        testFasts.append(todayFast)

        let streakInfo = StreakCalculator.calculate(from: testFasts, calendar: calendar, relativeTo: Date())
        XCTAssertEqual(streakInfo.currentStreak, 1)
        XCTAssertEqual(streakInfo.bestStreak, 3)
    }

    func testStreakCalculatorDailyFastStatus() throws {
        let ctx = try XCTUnwrap(context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let goalFast = Fast(context: ctx)
        goalFast.id = UUID()
        goalFast.startDate = today.addingTimeInterval(3600)
        goalFast.endDate = goalFast.startDate?.addingTimeInterval(16 * 3600)
        goalFast.targetDuration = 16 * 3600
        goalFast.isCompleted = true

        let status = StreakCalculator.fastStatus(for: today, in: [goalFast], calendar: calendar)
        XCTAssertEqual(status, .goalMet(hours: 16.0))

        let emptyDate = calendar.date(byAdding: .day, value: -10, to: today) ?? today
        let emptyStatus = StreakCalculator.fastStatus(for: emptyDate, in: [goalFast], calendar: calendar)
        XCTAssertEqual(emptyStatus, .none)
    }

    func testDailyFastStatusUpdatesWhenFastIsShortenedOrExtended() throws {
        let ctx = try XCTUnwrap(context)
        let manager = FastManager(context: ctx)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = today.addingTimeInterval(3600)

        let fast = Fast(context: ctx)
        fast.id = UUID()
        fast.createdAt = start
        fast.startDate = start
        fast.endDate = start.addingTimeInterval(16 * 3600)
        fast.targetDuration = 16 * 3600
        fast.isCompleted = true

        var status = StreakCalculator.fastStatus(for: today, in: [fast], calendar: calendar)
        XCTAssertEqual(status, .goalMet(hours: 16.0))

        // Shorten to 8h (below target)
        manager.updateCompletedFast(fast, startDate: start, endDate: start.addingTimeInterval(8 * 3600))
        status = StreakCalculator.fastStatus(for: today, in: [fast], calendar: calendar)
        XCTAssertEqual(status, .partial(hours: 8.0))

        // Lengthen to 18h (above target)
        manager.updateCompletedFast(fast, startDate: start, endDate: start.addingTimeInterval(18 * 3600))
        status = StreakCalculator.fastStatus(for: today, in: [fast], calendar: calendar)
        XCTAssertEqual(status, .goalMet(hours: 18.0))
    }

    // MARK: - Multi-day fasts

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }

    private func utcDate(day: Int, hour: Int) -> Date {
        let components = DateComponents(year: 2026, month: 5, day: day, hour: hour)
        return utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func completedFast(_ ctx: NSManagedObjectContext, start: Date, hours: Double) -> Fast {
        let fast = Fast(context: ctx)
        fast.id = UUID()
        fast.startDate = start
        fast.endDate = start.addingTimeInterval(hours * 3600)
        fast.targetDuration = hours * 3600
        fast.isCompleted = true
        return fast
    }

    func testCreditedDaysAreStartDayPlusWholeDaysSpanned() {
        let calendar = utcCalendar
        // Overnight 16h: only the start day.
        XCTAssertEqual(
            StreakDays.credited(start: utcDate(day: 1, hour: 20), end: utcDate(day: 2, hour: 12), calendar: calendar),
            [utcDate(day: 1, hour: 0)]
        )
        // Exactly 24h from midnight: still only the start day.
        XCTAssertEqual(
            StreakDays.credited(start: utcDate(day: 1, hour: 0), end: utcDate(day: 2, hour: 0), calendar: calendar),
            [utcDate(day: 1, hour: 0)]
        )
        // 72h from Friday evening: Friday, Saturday, Sunday.
        XCTAssertEqual(
            StreakDays.credited(start: utcDate(day: 1, hour: 20), end: utcDate(day: 4, hour: 20), calendar: calendar),
            [utcDate(day: 1, hour: 0), utcDate(day: 2, hour: 0), utcDate(day: 3, hour: 0)]
        )
    }

    /// Regression: only the start day counted, so the days inside a long fast broke the streak.
    func testMultiDayFastDoesNotBreakTheStreak() throws {
        let ctx = try XCTUnwrap(context)
        let calendar = utcCalendar
        let fasts = [
            completedFast(ctx, start: utcDate(day: 1, hour: 20), hours: 16),
            completedFast(ctx, start: utcDate(day: 2, hour: 20), hours: 72),
            completedFast(ctx, start: utcDate(day: 5, hour: 20), hours: 16)
        ]

        let info = StreakCalculator.calculate(from: fasts, calendar: calendar, relativeTo: utcDate(day: 6, hour: 14))

        // Days 1, 2, 3, 4 and 5.
        XCTAssertEqual(info.currentStreak, 5)
        XCTAssertEqual(info.bestStreak, 5)
        XCTAssertEqual(info.totalCompletedFasts, 3)
    }

    func testDayFullyInsideALongFastShowsInTheHeatmap() throws {
        let ctx = try XCTUnwrap(context)
        let calendar = utcCalendar
        let fast = completedFast(ctx, start: utcDate(day: 1, hour: 20), hours: 72)

        XCTAssertEqual(StreakCalculator.fastStatus(for: utcDate(day: 1, hour: 12), in: [fast], calendar: calendar),
                       .goalMet(hours: 72))
        XCTAssertEqual(StreakCalculator.fastStatus(for: utcDate(day: 2, hour: 12), in: [fast], calendar: calendar),
                       .goalMet(hours: 24))
        XCTAssertEqual(StreakCalculator.fastStatus(for: utcDate(day: 3, hour: 12), in: [fast], calendar: calendar),
                       .goalMet(hours: 24))
        // Only partly covered, so not credited.
        XCTAssertEqual(StreakCalculator.fastStatus(for: utcDate(day: 4, hour: 12), in: [fast], calendar: calendar),
                       .none)
    }
}
