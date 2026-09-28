import CoreData
import XCTest
@testable import Fasted

@MainActor
final class ChallengeManagerTests: XCTestCase {
    var container: NSPersistentContainer?
    var directory: URL?
    var now = Date(timeIntervalSince1970: 1_772_904_600) // Monday, March 9, 2026.
    var preferences: ChallengePreferences?

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        directory = dir
        container = try open()

        let suiteName = "test_\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        preferences = ChallengePreferences(userDefaults: userDefaults)
    }

    override func tearDownWithError() throws {
        guard let container else { return }
        container.viewContext.reset()
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        self.container = nil
        if let dir = directory {
            try FileManager.default.removeItem(at: dir)
        }
        directory = nil
        preferences = nil
    }

    private func open() throws -> NSPersistentContainer {
        let result = NSPersistentContainer(name: "Fasted")
        let targetDir = try XCTUnwrap(directory)
        let description = NSPersistentStoreDescription(url: targetDir.appendingPathComponent("history.sqlite"))
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        result.persistentStoreDescriptions = [description]
        var loadError: Error?
        result.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return result
    }

    private func makeManager() throws -> ChallengeManager {
        let cont = try XCTUnwrap(container)
        let prefs = try XCTUnwrap(preferences)
        return ChallengeManager(container: cont, preferences: prefs, now: { self.now })
    }

    private func makeDraft(
        title: String = "24-Day Reset",
        days: Set<Int> = Set(1...7),
        duration: Int = 24
    ) -> ChallengeDraft {
        ChallengeDraft(
            title: title,
            reason: "Feel energized",
            dayCount: duration,
            timeZoneID: "America/New_York",
            commitments: [
                CommitmentDraft(
                    title: "Walk 20m",
                    cue: "After lunch",
                    smallStart: "Put shoes on",
                    weekdays: days
                )
            ]
        )
    }

    func testInitialStateWithEmptyStore() throws {
        let manager = try makeManager()
        XCTAssertNil(manager.activeChallenge)
        XCTAssertTrue(manager.archivedChallenges.isEmpty)
        XCTAssertNil(manager.errorMessage)
        XCTAssertFalse(manager.isChallengesEnabled)
        XCTAssertTrue(manager.scheduledCommitments(for: now).isEmpty)
        XCTAssertNil(manager.currentDayNumber)
        XCTAssertNil(manager.totalDays)
        XCTAssertEqual(manager.dayProgressFraction, 0)
    }

    func testStartChallengeEnablesFeatureAndSetsActive() throws {
        let manager = try makeManager()
        let draft = makeDraft()
        let challenge = try manager.startChallenge(draft: draft)

        XCTAssertTrue(manager.isChallengesEnabled)
        XCTAssertEqual(manager.activeChallenge?.id, challenge.id)
        XCTAssertEqual(manager.activeChallenge?.title, "24-Day Reset")
        XCTAssertEqual(manager.currentDayNumber, 1)
        XCTAssertEqual(manager.totalDays, 24)
        XCTAssertEqual(manager.dayProgressFraction, 1.0 / 24.0, accuracy: 0.001)
        XCTAssertEqual(manager.scheduledCommitments(for: now).count, 1)
    }

    func testCheckInAndCheckInStatus() throws {
        let manager = try makeManager()
        let challenge = try manager.startChallenge(draft: makeDraft())
        let commitment = try XCTUnwrap(challenge.commitments.first)

        XCTAssertFalse(manager.isCompleted(commitmentID: commitment.id, on: now))
        XCTAssertNil(manager.checkInStatus(for: commitment.id, on: now))
        XCTAssertFalse(manager.allScheduledDone(for: now))

        try manager.checkIn(commitmentID: commitment.id, on: now, status: .done)
        XCTAssertTrue(manager.isCompleted(commitmentID: commitment.id, on: now))
        XCTAssertEqual(manager.checkInStatus(for: commitment.id, on: now), .done)
        XCTAssertTrue(manager.allScheduledDone(for: now))

        try manager.checkIn(commitmentID: commitment.id, on: now, status: nil)
        XCTAssertFalse(manager.isCompleted(commitmentID: commitment.id, on: now))
        XCTAssertNil(manager.checkInStatus(for: commitment.id, on: now))
    }

    func testScheduledCommitmentsRespectWeekdayFilter() throws {
        let manager = try makeManager()
        let tomorrow = now.addingTimeInterval(86400)
        let tomorrowWeekday = Calendar.current.component(.weekday, from: tomorrow)

        // Create challenge with commitment scheduled only for tomorrow
        let draft = makeDraft(days: [tomorrowWeekday])
        _ = try manager.startChallenge(draft: draft)

        // Today is not scheduled
        XCTAssertTrue(manager.scheduledCommitments(for: now).isEmpty)

        // Tomorrow is scheduled
        XCTAssertEqual(manager.scheduledCommitments(for: tomorrow).count, 1)
    }

    func testReplaceActiveChallengeAtomically() throws {
        let manager = try makeManager()
        let first = try manager.startChallenge(draft: makeDraft(title: "First Challenge"))
        XCTAssertEqual(manager.activeChallenge?.id, first.id)

        let second = try manager.startChallenge(
            draft: makeDraft(title: "Second Challenge"),
            replacing: first.id
        )

        XCTAssertEqual(manager.activeChallenge?.id, second.id)
        XCTAssertEqual(manager.archivedChallenges.count, 1)
        XCTAssertEqual(manager.archivedChallenges.first?.id, first.id)
        XCTAssertNotNil(manager.archivedChallenges.first?.endedAt)
    }

    func testArchiveActiveChallengeEarly() throws {
        let manager = try makeManager()
        let challenge = try manager.startChallenge(draft: makeDraft())
        XCTAssertNotNil(manager.activeChallenge)

        try manager.archive(challengeID: challenge.id)

        XCTAssertNil(manager.activeChallenge)
        XCTAssertEqual(manager.archivedChallenges.count, 1)
        XCTAssertEqual(manager.archivedChallenges.first?.id, challenge.id)
        XCTAssertNotNil(manager.archivedChallenges.first?.endedAt)
    }

    func testDayProgressCalculations() throws {
        let manager = try makeManager()
        let challenge = try manager.startChallenge(draft: makeDraft(duration: 30))
        XCTAssertEqual(manager.currentDayNumber, 1)
        XCTAssertEqual(manager.totalDays, 30)

        // Advance 9 days to day 10
        self.now = challenge.startDate.addingTimeInterval(9 * 86400)
        manager.refresh()
        XCTAssertEqual(manager.currentDayNumber, 10)
        XCTAssertEqual(manager.dayProgressFraction, 10.0 / 30.0, accuracy: 0.001)

        // Advance to final day (day 30)
        self.now = challenge.startDate.addingTimeInterval(29 * 86400)
        manager.refresh()
        XCTAssertEqual(manager.currentDayNumber, 30)
        XCTAssertEqual(manager.dayProgressFraction, 1.0, accuracy: 0.001)
    }

    func testCheckInWithoutActiveChallengeThrows() throws {
        let manager = try makeManager()
        XCTAssertThrowsError(
            try manager.checkIn(commitmentID: UUID(), on: now, status: .done)
        ) { error in
            XCTAssertEqual(error as? ChallengeError, ChallengeError.staleChallenge)
        }
    }
}
