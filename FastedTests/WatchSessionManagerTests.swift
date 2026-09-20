import XCTest
@testable import Fasted

final class WatchSessionManagerTests: XCTestCase {
    private var coordinator: AppGroupCoordinator?
    private var testDefaults: UserDefaults?
    private var suiteName: String?

    override func setUp() {
        super.setUp()
        let suite = "test.solstice.watchsession.\(UUID().uuidString)"
        self.suiteName = suite
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        self.testDefaults = defaults
        let tempCommandsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)
            .appendingPathComponent("commands", isDirectory: true)
        coordinator = AppGroupCoordinator(
            userDefaults: defaults,
            appGroupId: suite,
            commandsDirectory: tempCommandsDir
        )
    }

    override func tearDown() {
        if let suite = suiteName {
            testDefaults?.removePersistentDomain(forName: suite)
        }
        testDefaults = nil
        coordinator = nil
        super.tearDown()
    }

    func testHandleIncomingValidStartFastCommand() {
        let startTime = Date(timeIntervalSince1970: 1700000000)
        let envelope = PendingCommandEnvelope(
            command: .startFast(
                startDate: startTime,
                duration: 16 * 3600,
                protocolType: "16:8"
            )
        )

        guard let payload = WatchPayload.encodeCommand(envelope) else {
            XCTFail("Failed to encode envelope")
            return
        }

        // Test decoding payload directly
        let decoded = WatchPayload.decodeCommand(from: payload)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.id, envelope.id)

        if case .startFast(let start, let duration, let proto) = decoded?.command {
            XCTAssertEqual(start.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(duration, 16 * 3600)
            XCTAssertEqual(proto, "16:8")
        } else {
            XCTFail("Decoded command was not startFast")
        }
    }

    func testHandleIncomingValidEndFastCommand() {
        let endTime = Date(timeIntervalSince1970: 1700057600)
        let envelope = PendingCommandEnvelope(command: .endFast(endDate: endTime))

        guard let payload = WatchPayload.encodeCommand(envelope) else {
            XCTFail("Failed to encode endFast envelope")
            return
        }

        let decoded = WatchPayload.decodeCommand(from: payload)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.id, envelope.id)

        if case .endFast(let end) = decoded?.command {
            XCTAssertEqual(end.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("Decoded command was not endFast")
        }
    }

    func testHandleIncomingCorruptedDictionary() {
        let invalidPayloads: [[String: Any]] = [
            [:],
            ["version": 1],
            ["command": "unknown"],
            ["payload": "not a real command"]
        ]

        for payload in invalidPayloads {
            let decoded = WatchPayload.decodeCommand(from: payload)
            XCTAssertNil(decoded, "Corrupted payload should decode to nil")
        }
    }

    func testOptimisticWatchSnapshotTransitions() {
        let idleSnapshot = FastingStateSnapshot.idle
        XCTAssertFalse(idleSnapshot.isFasting)

        let startDate = Date(timeIntervalSince1970: 1700000000)
        let started = idleSnapshot.startingNow(
            startDate: startDate,
            duration: 16 * 3600,
            protocolType: "16:8"
        )
        XCTAssertTrue(started.isFasting)
        XCTAssertEqual(started.startDate, startDate)
        XCTAssertEqual(started.targetDuration, 16 * 3600)
        XCTAssertEqual(started.protocolType, "16:8")

        // End fast after reaching goal
        let completedDate = startDate.addingTimeInterval(17 * 3600)
        let ended = started.endingNow(at: completedDate)
        XCTAssertFalse(ended.isFasting)
        XCTAssertNil(ended.startDate)
        XCTAssertEqual(ended.currentStreak, 1)
        XCTAssertEqual(ended.lastCompletedFastDate, completedDate)
    }
}
