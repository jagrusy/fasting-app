import XCTest
import CoreData
import CoreGraphics
@testable import Fasted

@MainActor
final class FastedTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var fastManager: FastManager?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        self.persistenceController = controller
        self.context = ctx
        self.fastManager = FastManager(context: ctx)
    }

    override func tearDownWithError() throws {
        fastManager = nil
        persistenceController = nil
        context = nil
        try super.tearDownWithError()
    }

    func testCoreDataStackInitialization() throws {
        XCTAssertNotNil(persistenceController)
        XCTAssertNotNil(context)
    }

    func testFastingProtocolPresets() {
        XCTAssertEqual(FastingProtocol.presets.count, 6)
        XCTAssertEqual(FastingProtocol.default.ratioString, "16:8")
        XCTAssertEqual(FastingProtocol.default.fastingSeconds, 57600.0)

        let warrior = FastingProtocol.from(protocolType: "20:4")
        XCTAssertEqual(warrior.name, "Warrior")
        XCTAssertEqual(warrior.fastingHours, 20)
        XCTAssertEqual(warrior.eatingHours, 4)

        let fallback = FastingProtocol.from(protocolType: "unknown")
        XCTAssertEqual(fallback.ratioString, "16:8")
    }

    func testFastManagerStartsAndEndsFast() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        let startTime = Date().addingTimeInterval(-1000)
        let fast = manager.startFast(startDate: startTime, targetDuration: 57600, protocolType: "16:8")

        XCTAssertTrue(manager.isFasting)
        XCTAssertNotNil(manager.activeFast)
        XCTAssertEqual(manager.activeFast?.id, fast.id)
        XCTAssertEqual(manager.activeFast?.protocolType, "16:8")

        let endTime = Date()
        manager.endFast(endDate: endTime, moodRating: 4)

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try ctx.fetch(request)
        XCTAssertEqual(results.count, 1)
        let saved = try XCTUnwrap(results.first)
        XCTAssertEqual(saved.id, fast.id)
        XCTAssertEqual(saved.endDate, endTime)
        XCTAssertEqual(saved.moodRating, 4)
    }

    func testFastManagerDeletesFast() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        let fast = manager.startFast(startDate: Date())
        XCTAssertTrue(manager.isFasting)

        manager.deleteFast(fast)
        XCTAssertFalse(manager.isFasting)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try ctx.fetch(request)
        XCTAssertEqual(results.count, 0)
    }

    func testFastManagerSnoozesFast() throws {
        let manager = try XCTUnwrap(fastManager)
        let fast = manager.startFast(startDate: Date(), targetDuration: 57600)
        XCTAssertEqual(fast.targetDuration, 57600)

        manager.snoozeFast(by: 1800)
        XCTAssertEqual(fast.targetDuration, 57600 + 1800)
    }

    func testFastManagerUpdatesCompletedFast() throws {
        let manager = try XCTUnwrap(fastManager)
        let start = Date().addingTimeInterval(-72000)
        let end = start.addingTimeInterval(50000)

        let fast = manager.startFast(startDate: start, targetDuration: 57600)
        manager.endFast(endDate: end)
        XCTAssertFalse(fast.isCompleted)

        let newStart = start.addingTimeInterval(-10000)
        let newEnd = end
        manager.updateCompletedFast(fast, startDate: newStart, endDate: newEnd)

        XCTAssertEqual(fast.startDate, newStart)
        XCTAssertEqual(fast.endDate, newEnd)
        XCTAssertTrue(fast.isCompleted)
    }

    func testFastManagerPreventsDuplicateActiveFasts() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        let first = manager.startFast(startDate: Date())
        let second = manager.startFast(startDate: Date().addingTimeInterval(10))

        XCTAssertEqual(first.id, second.id)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try ctx.fetch(request)
        XCTAssertEqual(results.count, 1)
    }

    func testFastManagerUpdatesActiveFast() throws {
        let manager = try XCTUnwrap(fastManager)
        _ = manager.startFast(startDate: Date(), targetDuration: 57600)
        let newStartDate = Date().addingTimeInterval(-3600)
        let newDuration: TimeInterval = 18 * 3600

        manager.updateActiveFast(startDate: newStartDate, targetDuration: newDuration)

        XCTAssertEqual(manager.activeFast?.startDate, newStartDate)
        XCTAssertEqual(manager.activeFast?.targetDuration, newDuration)
    }

    func testFastManagerUpdatesSelectedProtocol() throws {
        let manager = try XCTUnwrap(fastManager)
        XCTAssertEqual(manager.currentProtocol.ratioString, "16:8")

        manager.updateSelectedProtocol("18:6")
        XCTAssertEqual(manager.currentProtocol.ratioString, "18:6")
        XCTAssertEqual(manager.currentProtocol.fastingHours, 18)

        let fast = manager.startFast(startDate: Date())
        XCTAssertEqual(fast.protocolType, "18:6")
        XCTAssertEqual(fast.targetDuration, 18 * 3600)
    }

    func testNotificationScheduleEncodingAndUpdating() throws {
        let manager = try XCTUnwrap(fastManager)
        let defaultSchedule = manager.notificationSchedule
        XCTAssertEqual(defaultSchedule.selectedDays.count, 7)

        var customSchedule = defaultSchedule
        customSchedule.selectedDays = [2, 3, 4, 5, 6]
        customSchedule.notifyOnGoalReached = false

        manager.updateNotificationSchedule(enabled: true, schedule: customSchedule)
        XCTAssertTrue(manager.userSettings?.notificationsEnabled == true)
        XCTAssertEqual(manager.notificationSchedule.selectedDays, [2, 3, 4, 5, 6])
        XCTAssertFalse(manager.notificationSchedule.notifyOnGoalReached)
    }

    func testCenterDisplayModeCycle() {
        XCTAssertEqual(CenterDisplayMode.elapsed.next, .remaining)
        XCTAssertEqual(CenterDisplayMode.remaining.next, .percentage)
        XCTAssertEqual(CenterDisplayMode.percentage.next, .elapsed)
    }

    // MARK: - Validation & Data Management Tests

    func testValidateIntervalRejectsFutureDates() throws {
        let manager = try XCTUnwrap(fastManager)
        let futureStart = Date().addingTimeInterval(3600)
        let validation = manager.validateInterval(startDate: futureStart)
        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.message, "Start time cannot be in the future.")

        let pastStart = Date().addingTimeInterval(-7200)
        let futureEnd = Date().addingTimeInterval(1800)
        let endValidation = manager.validateInterval(startDate: pastStart, endDate: futureEnd)
        XCTAssertFalse(endValidation.isValid)
        XCTAssertEqual(endValidation.message, "End time cannot be in the future.")
    }

    func testValidateIntervalDetectsOverlap() throws {
        let manager = try XCTUnwrap(fastManager)
        let now = Date()
        let fast1Start = now.addingTimeInterval(-86400)
        let fast1End = now.addingTimeInterval(-43200)

        let fast1 = manager.startFast(startDate: fast1Start, targetDuration: 16 * 3600)
        manager.endFast(endDate: fast1End)

        // Attempt overlapping interval
        let overlapStart = now.addingTimeInterval(-64800)
        let overlapEnd = now.addingTimeInterval(-21600)
        let overlapValidation = manager.validateInterval(startDate: overlapStart, endDate: overlapEnd)
        XCTAssertFalse(overlapValidation.isValid)
        XCTAssertTrue(overlapValidation.message?.contains("overlaps") == true)

        // Valid non-overlapping interval
        let validStart = now.addingTimeInterval(-36000)
        let validEnd = now.addingTimeInterval(-7200)
        let validValidation = manager.validateInterval(startDate: validStart, endDate: validEnd)
        XCTAssertTrue(validValidation.isValid)

        // Self-exclusion test
        let selfValidation = manager.validateInterval(
            startDate: fast1Start,
            endDate: fast1End,
            excludingFastId: fast1.id
        )
        XCTAssertTrue(selfValidation.isValid)
    }

    func testClearAllFastingData() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        _ = manager.startFast(startDate: Date().addingTimeInterval(-3600))
        manager.endFast(endDate: Date())
        _ = manager.startFast(startDate: Date())

        XCTAssertTrue(manager.isFasting)

        manager.clearAllFastingData()

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let count = try ctx.count(for: request)
        XCTAssertEqual(count, 0)
    }

    // MARK: - Streak Calculator Unit Tests

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

    func testPreviewPersistenceController() throws {
        let preview = PersistenceController.preview
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try preview.container.viewContext.fetch(request)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }
}
