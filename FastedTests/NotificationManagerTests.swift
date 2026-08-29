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
}
