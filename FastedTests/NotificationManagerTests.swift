import XCTest
import CoreData
import UserNotifications
@testable import Fasted

@MainActor
final class NotificationManagerTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var fastManager: FastManager?
    var testDefaults: UserDefaults?
    var testDefaultsSuiteName: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let suiteName = "NotificationManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.persistenceController = controller
        self.context = ctx
        self.testDefaultsSuiteName = suiteName
        self.testDefaults = defaults
        self.fastManager = FastManager(context: ctx, defaults: defaults)
    }

    override func tearDownWithError() throws {
        fastManager = nil
        persistenceController = nil
        context = nil
        if let suiteName = testDefaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        testDefaultsSuiteName = nil
        try super.tearDownWithError()
    }

    func testNotificationScheduleDefaultIncludesStageNotifications() {
        let schedule = NotificationSchedule.default
        XCTAssertTrue(schedule.notifyOnStageChange)
        XCTAssertTrue(schedule.notifyOnGoalReached)
    }

    func testNotificationScheduleBackwardCompatibilityDecoding() throws {
        // JSON simulating older app version before notifyOnStageChange existed
        let jsonWithoutStageChange = """
        {
            "startReminderTime": 0,
            "endReminderTime": 0,
            "selectedDays": [1, 2, 3, 4, 5, 6, 7],
            "notifyOnGoalReached": true
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(
            NotificationSchedule.self,
            from: Data(jsonWithoutStageChange.utf8)
        )

        XCTAssertTrue(decoded.notifyOnStageChange)
        XCTAssertTrue(decoded.notifyOnGoalReached)
    }

    func testFutureStageBoundariesForNewFast() {

        let now = Date()
        let boundaries = NotificationManager.futureStageBoundaries(startDate: now, now: now)

        // Stages after hour 0: glycogenDepletion (4h), fatBurning (12h), autophagy (18h), deepKetosis (24h)
        XCTAssertEqual(boundaries.count, 4)
        XCTAssertEqual(boundaries[0].stage, .glycogenDepletion)
        XCTAssertEqual(boundaries[0].timeInterval, 4 * 3600, accuracy: 1.0)
        XCTAssertEqual(boundaries[1].stage, .fatBurning)
        XCTAssertEqual(boundaries[1].timeInterval, 12 * 3600, accuracy: 1.0)
        XCTAssertEqual(boundaries[2].stage, .autophagy)
        XCTAssertEqual(boundaries[2].timeInterval, 18 * 3600, accuracy: 1.0)
        XCTAssertEqual(boundaries[3].stage, .deepKetosis)
        XCTAssertEqual(boundaries[3].timeInterval, 24 * 3600, accuracy: 1.0)
    }

    func testFutureStageBoundariesForFastStarted13HoursAgo() {
        let now = Date()
        let started13hAgo = now.addingTimeInterval(-13 * 3600)
        let boundaries = NotificationManager.futureStageBoundaries(startDate: started13hAgo, now: now)

        // 4h and 12h boundaries are already in the past. Only 18h and 24h boundaries remain in future.
        XCTAssertEqual(boundaries.count, 2)
        XCTAssertEqual(boundaries[0].stage, .autophagy)
        XCTAssertEqual(boundaries[0].timeInterval, 5 * 3600, accuracy: 1.0) // 18 - 13 = 5h
        XCTAssertEqual(boundaries[1].stage, .deepKetosis)
        XCTAssertEqual(boundaries[1].timeInterval, 11 * 3600, accuracy: 1.0) // 24 - 13 = 11h
    }

    func testStageNotificationIdentifiers() {
        XCTAssertEqual(NotificationManager.stageNotificationIdentifier(for: .bloodSugarReset), "fast_stage_0")
        XCTAssertEqual(NotificationManager.stageNotificationIdentifier(for: .glycogenDepletion), "fast_stage_1")
        XCTAssertEqual(NotificationManager.stageNotificationIdentifier(for: .fatBurning), "fast_stage_2")
        XCTAssertEqual(NotificationManager.stageNotificationIdentifier(for: .autophagy), "fast_stage_3")
        XCTAssertEqual(NotificationManager.stageNotificationIdentifier(for: .deepKetosis), "fast_stage_4")
    }

    func testStartFastCallbackStartsFast() throws {
        let manager = try XCTUnwrap(fastManager)
        XCTAssertFalse(manager.isFasting)

        NotificationManager.shared.onStartFastRequested?()

        // Wait a tick for Task @MainActor to execute
        let exp = expectation(description: "Fast started via notification callback")
        DispatchQueue.main.async {
            XCTAssertTrue(manager.isFasting)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - Day milestones

    func testDayMilestonesFireAtEachWholeDayBeforeTheGoal() {
        let now = Date()
        let milestones = NotificationManager.futureDayMilestones(startDate: now, targetDuration: 72 * 3600, now: now)

        // Day 1 is covered by the 24h stage notification and day 3 is the goal itself.
        XCTAssertEqual(milestones.count, 1)
        XCTAssertEqual(milestones[0].hours, 48)
        XCTAssertEqual(milestones[0].hoursRemaining, 24)
        XCTAssertEqual(milestones[0].timeInterval, 48 * 3600, accuracy: 1.0)
    }

    func testNoDayMilestonesForFastsUnderTwoDays() {
        let now = Date()
        for hours in [16.0, 24, 36, 48] {
            XCTAssertTrue(
                NotificationManager.futureDayMilestones(startDate: now, targetDuration: hours * 3600, now: now).isEmpty,
                "\(hours)h"
            )
        }
    }

    func testDayMilestonesSkipThoseAlreadyPassed() {
        let now = Date()
        let started50hAgo = now.addingTimeInterval(-50 * 3600)
        let milestones = NotificationManager.futureDayMilestones(
            startDate: started50hAgo,
            targetDuration: 100 * 3600,
            now: now
        )

        XCTAssertEqual(milestones.map(\.hours), [72, 96])
        XCTAssertEqual(milestones[0].timeInterval, 22 * 3600, accuracy: 1.0)
        XCTAssertEqual(milestones[1].hoursRemaining, 4)
    }

    // MARK: - Start reminders

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }

    /// 2026-05-04 is a Monday.
    private func utcDate(day: Int, hour: Int) -> Date {
        let components = DateComponents(year: 2026, month: 5, day: day, hour: hour)
        return utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func reminderSchedule(days: Set<Int>) -> NotificationSchedule {
        NotificationSchedule(
            startReminderTime: utcDate(day: 1, hour: 20),
            endReminderTime: utcDate(day: 1, hour: 12),
            selectedDays: days
        )
    }

    func testStartRemindersRepeatWeeklyWhenNotFasting() {
        let plan = NotificationManager.startReminderPlan(
            schedule: reminderSchedule(days: [1, 4, 6]),
            now: utcDate(day: 4, hour: 12),
            calendar: utcCalendar
        )

        XCTAssertEqual(plan, [1, 4, 6].map { NotificationManager.StartReminder(weekday: $0) })
    }

    /// Regression: the weekly repeat fired during a multi-day fast. Only the weekdays whose next
    /// reminder lands inside the fast move past the goal; the rest keep repeating, so reminders
    /// continue even if the app isn't reopened.
    func testStartRemindersDuringTheActiveFastMovePastItsGoal() {
        // Monday 4th 21:00, fast reaches its goal Thursday 7th 21:00.
        let plan = NotificationManager.startReminderPlan(
            schedule: reminderSchedule(days: Set(1...7)),
            now: utcDate(day: 4, hour: 21),
            suppressUntil: utcDate(day: 7, hour: 21),
            calendar: utcCalendar
        )

        // Weekdays: 1 = Sunday … 7 = Saturday. Tue/Wed/Thu fall inside the fast, so each gets its
        // next four weeks after the goal as one-off reminders instead of a weekly repeat.
        func deferred(from day: Int) -> [Date] {
            (0..<NotificationManager.deferredReminderWeeks).compactMap {
                utcCalendar.date(byAdding: .day, value: 7 * $0, to: utcDate(day: day, hour: 20))
            }
        }
        XCTAssertEqual(NotificationManager.deferredReminderWeeks, 4)
        XCTAssertEqual(plan, [
            NotificationManager.StartReminder(weekday: 1),
            NotificationManager.StartReminder(weekday: 2),
            NotificationManager.StartReminder(weekday: 3, deferredDates: deferred(from: 12)),
            NotificationManager.StartReminder(weekday: 4, deferredDates: deferred(from: 13)),
            NotificationManager.StartReminder(weekday: 5, deferredDates: deferred(from: 14)),
            NotificationManager.StartReminder(weekday: 6),
            NotificationManager.StartReminder(weekday: 7)
        ])
    }

    func testWeekZeroKeepsTheLegacyWeeklyIdentifier() {
        XCTAssertEqual(NotificationManager.startReminderIdentifier(weekday: 3, week: 0), "recurring_start_day_3")
        XCTAssertEqual(NotificationManager.startReminderIdentifier(weekday: 3, week: 2), "recurring_start_day_3_2")
    }

    func testPastSuppressionLeavesAllRemindersRepeating() {
        let plan = NotificationManager.startReminderPlan(
            schedule: reminderSchedule(days: [3]),
            now: utcDate(day: 4, hour: 21),
            suppressUntil: utcDate(day: 4, hour: 9),
            calendar: utcCalendar
        )

        XCTAssertEqual(plan, [NotificationManager.StartReminder(weekday: 3)])
    }
}
