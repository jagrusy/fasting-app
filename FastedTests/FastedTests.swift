import XCTest
import CoreData
import CoreGraphics
@testable import Fasted

@MainActor
final class FastedTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var fastManager: FastManager?
    var testDefaults: UserDefaults?
    var testDefaultsSuiteName: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let suiteName = "FastedTests.\(UUID().uuidString)"
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

    func testFastManagerSnoozeDoesNotRewriteGoal() throws {
        // Regression test: snoozing used to add the extension directly onto targetDuration, which
        // desynced a fast's stored goal from its protocolType (e.g. a 16:8 fast with a 1h snooze would
        // read "101% of 17h goal" in history instead of "108% of 16h goal"). Snoozing should only delay
        // when the goal notification re-fires, never change what the goal itself is.
        let manager = try XCTUnwrap(fastManager)
        let fast = manager.startFast(startDate: Date(), targetDuration: 57600, protocolType: "16:8")
        XCTAssertEqual(fast.targetDuration, 57600)

        manager.snoozeFast(by: 1800)
        XCTAssertEqual(fast.targetDuration, 57600)
        XCTAssertEqual(fast.protocolType, "16:8")

        manager.snoozeFast(by: 3600)
        XCTAssertEqual(fast.targetDuration, 57600)
        XCTAssertEqual(fast.protocolType, "16:8")
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

    func testDiscardActiveFastRemovesItFromHistory() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        _ = manager.startFast(startDate: Date().addingTimeInterval(-3600))
        XCTAssertTrue(manager.isFasting)

        manager.discardActiveFast()

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let count = try ctx.count(for: request)
        XCTAssertEqual(count, 0)
    }

    func testDeleteFastWithDuplicateIdDoesNotClearUnrelatedActiveFast() throws {
        // Regression test: deleteFast used to compare `activeFast?.id == fast.id` by value. If an
        // unrelated fast ever ends up sharing the active fast's UUID (e.g. a future import/sync bug —
        // `id` has no uniqueness constraint in the Core Data model), that value comparison would wrongly
        // report a match and clear the real active fast out from under the user. Comparing object
        // identity instead means only the record actually being deleted can ever do that.
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        let active = manager.startFast(startDate: Date())
        let sharedId = try XCTUnwrap(active.id)

        let unrelated = Fast(context: ctx)
        unrelated.id = sharedId
        unrelated.startDate = Date().addingTimeInterval(-86400)
        unrelated.endDate = Date().addingTimeInterval(-70000)
        unrelated.targetDuration = 16 * 3600
        unrelated.createdAt = Date()
        unrelated.updatedAt = Date()
        try ctx.save()

        manager.deleteFast(unrelated)

        XCTAssertTrue(manager.isFasting)
        XCTAssertEqual(manager.activeFast, active)
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

    func testUpdateSelectedProtocolAloneLeavesActiveFastUntouched() throws {
        let manager = try XCTUnwrap(fastManager)
        let fast = manager.startFast(startDate: Date(), targetDuration: 16 * 3600, protocolType: "16:8")

        manager.updateSelectedProtocol("18:6")

        XCTAssertEqual(fast.protocolType, "16:8")
        XCTAssertEqual(fast.targetDuration, 16 * 3600)
    }

    func testUpdateActiveFastCanRetargetRunningFastToNewProtocol() throws {
        let manager = try XCTUnwrap(fastManager)
        let start = Date().addingTimeInterval(-3600)
        let fast = manager.startFast(startDate: start, targetDuration: 16 * 3600, protocolType: "16:8")

        manager.updateActiveFast(startDate: start, targetDuration: 18 * 3600, protocolType: "18:6")

        XCTAssertEqual(fast.protocolType, "18:6")
        XCTAssertEqual(fast.targetDuration, 18 * 3600)
        XCTAssertEqual(fast.startDate, start)
    }

    func testFastingProtocolLabelDetectsDivergedGoal() {
        // A fast whose targetDuration still matches its protocol's preset shows the ratio...
        XCTAssertEqual(
            FastingProtocol.label(forTargetDuration: 16 * 3600, protocolType: "16:8"),
            "16:8"
        )
        // ...but one that has drifted (e.g. via a snoozed pre-fix history entry) reads as Custom
        // rather than silently showing a ratio that contradicts the stored goal.
        XCTAssertEqual(
            FastingProtocol.label(forTargetDuration: 17 * 3600, protocolType: "16:8"),
            "Custom"
        )
        XCTAssertEqual(
            FastingProtocol.label(forTargetDuration: 16 * 3600, protocolType: nil),
            "Custom"
        )
    }

    func testNotificationScheduleDefaultUsesTodaysDate() {
        let schedule = NotificationSchedule.default
        let calendar = Calendar.current

        XCTAssertTrue(calendar.isDateInToday(schedule.startReminderTime))
        XCTAssertEqual(calendar.component(.hour, from: schedule.startReminderTime), 20)
        XCTAssertEqual(calendar.component(.minute, from: schedule.startReminderTime), 0)
        XCTAssertTrue(calendar.isDateInToday(schedule.endReminderTime))
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

    func testPreviewPersistenceController() throws {
        let preview = PersistenceController.preview
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try preview.container.viewContext.fetch(request)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }
}
