import CoreData
import XCTest
@testable import Fasted

@MainActor
final class ChallengeStoreTests: XCTestCase {
    var container: NSPersistentContainer?
    var directory: URL?
    var now = Date(timeIntervalSince1970: 1_772_904_600) // Around the 2026 spring DST transition.

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        directory = dir
        container = try open()
    }

    override func tearDownWithError() throws {
        try close()
        if let dir = directory {
            try FileManager.default.removeItem(at: dir)
        }
        directory = nil
    }

    func open(model: NSManagedObjectModel? = nil) throws -> NSPersistentContainer {
        let result = model.map { NSPersistentContainer(name: "Fasted", managedObjectModel: $0) }
            ?? NSPersistentContainer(name: "Fasted")
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

    func close() throws {
        guard let container else { return }
        container.viewContext.reset()
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores { try coordinator.remove(store) }
        self.container = nil
    }

    func draft(days: Set<Int> = Set(1...7)) -> ChallengeDraft {
        ChallengeDraft(title: "My 24-day reset", timeZoneID: "America/New_York", commitments: [
            CommitmentDraft(title: "Walk for 20 minutes", cue: "After lunch",
                            smallStart: "Put on walking shoes", weekdays: days)
        ])
    }

    func store(failing: Bool = false) -> ChallengeStore {
        guard let container else {
            XCTFail("Missing test container")
            return ChallengeStore(container: NSPersistentContainer(name: "Fasted"))
        }
        return ChallengeStore(container: container, now: { self.now }, save: {
            if failing { throw CocoaError(.fileWriteUnknown) }
            try $0.save()
        })
    }

    func testCreateCheckInAndReopenWithoutOriginalStore() throws {
        var writer: ChallengeStore? = store()
        let challenge = try XCTUnwrap(writer).start(draft())
        let commitment = try XCTUnwrap(challenge.commitments.first)
        try writer?.checkIn(challengeID: challenge.id, commitmentID: commitment.id, on: now, status: .done)
        writer = nil
        try close()
        container = try open()
        let reopened = try XCTUnwrap(store().challenges().first)
        XCTAssertEqual(reopened.id, challenge.id)
        XCTAssertEqual(reopened.commitments, challenge.commitments)
        XCTAssertEqual(reopened.checkIns.count, 1)
        XCTAssertEqual(reopened.checkIns.first?.status, .done)
        XCTAssertEqual(reopened.checkIns.first?.recordedAt, now)
    }

    func testDuplicateCheckInIsIdempotentAndCorrectionsPreserveOriginalRecordedTime() throws {
        let writer = store()
        let challenge = try writer.start(draft())
        let commitment = try XCTUnwrap(challenge.commitments.first)
        let recorded = now
        try writer.checkIn(challengeID: challenge.id, commitmentID: commitment.id, on: now, status: .done)
        now = now.addingTimeInterval(60)
        try writer.checkIn(challengeID: challenge.id, commitmentID: commitment.id, on: now, status: .done)
        var result = try XCTUnwrap(writer.challenges().first)
        XCTAssertEqual(result.checkIns.count, 1)
        XCTAssertEqual(result.checkIns.first?.updatedAt, recorded)
        try writer.checkIn(challengeID: challenge.id, commitmentID: commitment.id, on: now, status: .notDone)
        result = try XCTUnwrap(writer.challenges().first)
        XCTAssertEqual(result.checkIns.first?.recordedAt, recorded)
        XCTAssertEqual(result.checkIns.first?.updatedAt, now)
        XCTAssertEqual(result.checkIns.first?.status, .notDone)
        try writer.checkIn(challengeID: challenge.id, commitmentID: commitment.id, on: now, status: nil)
        XCTAssertTrue(try XCTUnwrap(writer.challenges().first).checkIns.isEmpty)
    }

    func testFailedReplacementPreservesOriginalAndDoesNotSaveUnrelatedEdits() throws {
        let original = try store().start(draft())
        let currentContainer = try XCTUnwrap(container)
        let pending = NSEntityDescription.insertNewObject(
            forEntityName: "UserSettings",
            into: currentContainer.viewContext
        )
        pending.setValue(UUID(), forKey: "id")
        XCTAssertThrowsError(try store(failing: true).start(draft(), replacing: original.id))
        XCTAssertTrue(pending.isInserted)
        var result = try store().challenges()
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result.first?.endedAt)
        let replacement = try store().start(draft(), replacing: original.id)
        result = try store().challenges()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.filter { $0.isActive(at: now) }.map(\.id), [replacement.id])
        XCTAssertEqual(result.first(where: { $0.id == original.id })?.endedAt, now)
        XCTAssertTrue(pending.isInserted)
        let context = try XCTUnwrap(container).newBackgroundContext()
        try context.performAndWait {
            XCTAssertEqual(try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "UserSettings")), 0)
        }
    }

    func testRejectsSecondActiveAndStaleReplacement() throws {
        let challenge = try store().start(draft())
        XCTAssertThrowsError(try store().start(draft()))
        XCTAssertThrowsError(try store().start(draft(), replacing: UUID()))
        XCTAssertEqual(try store().challenges().map(\.id), [challenge.id])
    }

    func testFailedCheckInAndFailedCreationLeaveNoRows() throws {
        XCTAssertThrowsError(try store(failing: true).start(draft()))
        XCTAssertTrue(try store().challenges().isEmpty)
        let challenge = try store().start(draft())
        let commitment = try XCTUnwrap(challenge.commitments.first)
        XCTAssertThrowsError(try store(failing: true).checkIn(
            challengeID: challenge.id, commitmentID: commitment.id, on: now, status: .done
        ))
        XCTAssertTrue(try XCTUnwrap(store().challenges().first).checkIns.isEmpty)
    }

    func testRejectsFutureUnscheduledAndOutsideChallengeDays() throws {
        let challenge = try store().start(draft(days: [2]))
        let commitment = try XCTUnwrap(challenge.commitments.first)
        for day in [challenge.startDate.addingTimeInterval(-86400), challenge.endDate, now.addingTimeInterval(86400)] {
            XCTAssertThrowsError(try store().checkIn(
                challengeID: challenge.id, commitmentID: commitment.id, on: day, status: .done
            ))
        }
        let sunday = try XCTUnwrap(challenge.calendar.nextDate(
            after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime
        ))
        now = sunday
        XCTAssertThrowsError(try store().checkIn(
            challengeID: challenge.id, commitmentID: commitment.id, on: now, status: .done
        ))
    }

    func testExpiredChallengeAllowsNewOneAndPreservesUnrecordedDays() throws {
        let challenge = try store().start(draft())
        now = challenge.endDate
        let replacement = try store().start(draft())
        let old = try XCTUnwrap(store().challenges().first(where: { $0.id == challenge.id }))
        XCTAssertFalse(old.isActive(at: now))
        XCTAssertTrue(replacement.isActive(at: now))
        XCTAssertNil(old.endedAt)
        XCTAssertEqual(old.scheduledDays(for: old.commitments[0], through: now).count, 24)
        XCTAssertEqual(old.completedCount(for: old.commitments[0], through: now), 0)
    }
}
