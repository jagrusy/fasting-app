import XCTest
@testable import Fasted

final class AppGroupCoordinatorTests: XCTestCase {
    private var testDefaults: UserDefaults?
    private var coordinator: AppGroupCoordinator?
    private var testSuiteName: String?

    override func setUp() {
        super.setUp()
        let suiteName = "test.solstice.appgroup.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.testSuiteName = suiteName
        self.testDefaults = defaults
        self.coordinator = AppGroupCoordinator(userDefaults: defaults, appGroupId: suiteName)
    }

    override func tearDown() {
        if let suite = testSuiteName {
            testDefaults?.removePersistentDomain(forName: suite)
        }
        testDefaults = nil
        coordinator = nil
        super.tearDown()
    }

    func testSnapshotWriteAndRead() {
        guard let coordinator = coordinator else {
            XCTFail("Coordinator not initialized")
            return
        }
        let initial = coordinator.readSnapshot()

        XCTAssertEqual(initial, .idle)

        let startDate = Date(timeIntervalSince1970: 1700000000)
        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: startDate,
            targetDuration: 18 * 3600,
            protocolType: "18:6",
            currentStreak: 3,
            longestStreak: 7,
            lastCompletedFastDate: nil,
            updatedAt: Date()
        )

        coordinator.writeSnapshot(snapshot)
        let read = coordinator.readSnapshot()
        XCTAssertEqual(read.isFasting, true)
        XCTAssertEqual(read.startDate, startDate)
        XCTAssertEqual(read.targetDuration, 18 * 3600)
        XCTAssertEqual(read.protocolType, "18:6")
        XCTAssertEqual(read.currentStreak, 3)
        XCTAssertEqual(read.longestStreak, 7)
    }

    func testCommandQueueFIFOAndDrain() {
        guard let coordinator = coordinator else {
            XCTFail("Coordinator not initialized")
            return
        }
        let empty = coordinator.drainPendingCommands()

        XCTAssertTrue(empty.isEmpty)

        let start = Date(timeIntervalSince1970: 1700000000)
        let cmd1 = FastingActionCommand.startFast(startDate: start, duration: 16 * 3600, protocolType: "16:8")
        let cmd2 = FastingActionCommand.snoozeFast(extensionSeconds: 3600)
        let cmd3 = FastingActionCommand.endFast(endDate: start.addingTimeInterval(17 * 3600))

        coordinator.enqueueCommand(cmd1)
        coordinator.enqueueCommand(cmd2)
        coordinator.enqueueCommand(cmd3)

        let drained = coordinator.drainPendingCommands()
        XCTAssertEqual(drained.count, 3)
        XCTAssertEqual(drained[0].command, cmd1)
        XCTAssertEqual(drained[1].command, cmd2)
        XCTAssertEqual(drained[2].command, cmd3)

        // Verify queue is now empty
        let drainedAgain = coordinator.drainPendingCommands()
        XCTAssertTrue(drainedAgain.isEmpty)
    }
}
