import XCTest
@testable import Fasted

final class AppGroupResilienceTests: XCTestCase {
    private var commandsDir: URL?

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("solstice-resilience-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        commandsDir = dir
    }

    override func tearDown() {
        if let dir = commandsDir {
            try? FileManager.default.removeItem(at: dir)
        }
        commandsDir = nil
        super.tearDown()
    }

    private func makeCoordinator(suite: String = "test.solstice.\(UUID().uuidString)") -> AppGroupCoordinator {
        AppGroupCoordinator(
            userDefaults: UserDefaults(suiteName: suite) ?? .standard,
            appGroupId: suite,
            commandsDirectory: commandsDir
        )
    }

    /// Pins the reachable half of the flag's contract. The bug actually fixed alongside this —
    /// `isUsingSharedContainer` reporting true while reads had fallen through to `.standard` —
    /// needed a container to exist while `UserDefaults(suiteName:)` returned nil, which cannot be
    /// constructed here: the suite initialiser only fails for names like the bundle id, and those
    /// never have a container. Verified by inspection instead; this guards the branch that is
    /// testable.
    func testSharedContainerFlagIsFalseWhenTheAppGroupIsUnavailable() {
        let coordinator = AppGroupCoordinator(appGroupId: "group.solstice.definitely.not.entitled")
        XCTAssertFalse(coordinator.isUsingSharedContainer)
    }

    /// Regression: the removal used to sit outside the decode check, so an unparseable command was
    /// deleted along with the valid ones.
    func testMalformedCommandIsQuarantinedRatherThanDeleted() throws {
        let coordinator = makeCoordinator()
        let dir = try XCTUnwrap(commandsDir)

        coordinator.enqueueCommand(.startFast(
            startDate: Date(timeIntervalSince1970: 1700000000),
            duration: 16 * 3600,
            protocolType: "16:8"
        ))

        let corrupt = dir.appendingPathComponent("0000000000.000000_\(UUID().uuidString).json")
        try Data("{ not json at all".utf8).write(to: corrupt)

        let drained = coordinator.drainPendingCommands()

        // The valid command still comes through, and the corrupt one does not masquerade as one.
        XCTAssertEqual(drained.count, 1)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: corrupt.path),
            "corrupt file should have been moved out of the queue"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: corrupt.appendingPathExtension("quarantined").path),
            "corrupt file should be preserved for diagnosis, not destroyed"
        )
    }

    /// A quarantined file must not be re-read forever, or it becomes a poison pill.
    func testQuarantinedCommandIsNotReprocessedOnTheNextDrain() throws {
        let coordinator = makeCoordinator()
        let dir = try XCTUnwrap(commandsDir)

        let corrupt = dir.appendingPathComponent("0000000000.000000_\(UUID().uuidString).json")
        try Data("{ not json at all".utf8).write(to: corrupt)

        XCTAssertTrue(coordinator.drainPendingCommands().isEmpty)
        XCTAssertTrue(coordinator.drainPendingCommands().isEmpty)
    }

    /// The Control Center tile opens the app and leaves this behind to say which tab to land on.
    func testPendingDeepLinkRoundTripsAndIsConsumedOnce() {
        let coordinator = makeCoordinator()
        XCTAssertNil(coordinator.consumePendingDeepLink())

        coordinator.writePendingDeepLink(.fastTracker)
        XCTAssertEqual(coordinator.consumePendingDeepLink(), .fastTracker)

        // Consuming clears it, so a later unrelated foreground doesn't yank the user to a tab
        // they never asked for.
        XCTAssertNil(coordinator.consumePendingDeepLink())
    }

    func testPendingDeepLinkOverwritesRatherThanQueues() {
        let coordinator = makeCoordinator()
        coordinator.writePendingDeepLink(.fastTracker)
        coordinator.writePendingDeepLink(.history)

        XCTAssertEqual(coordinator.consumePendingDeepLink(), .history)
        XCTAssertNil(coordinator.consumePendingDeepLink())
    }

    func testValidCommandsAreStillRemovedAfterDraining() {
        let coordinator = makeCoordinator()
        coordinator.enqueueCommand(.endFast(endDate: Date(timeIntervalSince1970: 1700000000)))

        XCTAssertEqual(coordinator.drainPendingCommands().count, 1)
        XCTAssertTrue(coordinator.drainPendingCommands().isEmpty, "a drained command must not repeat")
    }
}
