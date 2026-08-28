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
}
