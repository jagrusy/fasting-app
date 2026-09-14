import XCTest
import CoreData
import Combine
@testable import Fasted

final class FastExtensionsTests: XCTestCase {
    private var context: NSManagedObjectContext {
        PersistenceController.preview.container.viewContext
    }
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testCompletedFastGoalMet() {
        let fast = Fast(context: context)
        fast.id = UUID()
        let start = Date(timeIntervalSince1970: 100000)
        let end = start.addingTimeInterval(16 * 3600) // Exactly 16h
        fast.startDate = start
        fast.endDate = end
        fast.targetDuration = 16 * 3600
        fast.isCompleted = true

        XCTAssertEqual(fast.duration(), 16 * 3600)
        XCTAssertTrue(fast.isGoalMet)
        XCTAssertEqual(fast.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(fast.formattedDuration, "16h")
        XCTAssertEqual(fast.formattedGoal, "16h")
    }

    func testCompletedFastEndedEarly() {
        let fast = Fast(context: context)
        fast.id = UUID()
        let start = Date(timeIntervalSince1970: 100000)
        let end = start.addingTimeInterval(14 * 3600 + 30 * 60) // 14h 30m
        fast.startDate = start
        fast.endDate = end
        fast.targetDuration = 16 * 3600
        fast.isCompleted = false

        XCTAssertEqual(fast.duration(), 14 * 3600 + 30 * 60)
        XCTAssertFalse(fast.isGoalMet)
        XCTAssertEqual(fast.progress, (14.5 / 16.0), accuracy: 0.001)
        XCTAssertEqual(fast.formattedDuration, "14h 30m")
        XCTAssertEqual(fast.formattedGoal, "16h")
    }

    func testActiveFastDurationRelativeToNow() {
        let fast = Fast(context: context)
        fast.id = UUID()
        let start = Date(timeIntervalSince1970: 100000)
        fast.startDate = start
        fast.endDate = nil
        fast.targetDuration = 16 * 3600

        let relativeNow = start.addingTimeInterval(8 * 3600) // 8h in
        XCTAssertEqual(fast.duration(relativeTo: relativeNow), 8 * 3600)
        XCTAssertFalse(fast.isGoalMet(relativeTo: relativeNow))
        XCTAssertEqual(fast.progress(relativeTo: relativeNow), 0.5, accuracy: 0.001)
        XCTAssertEqual(fast.formattedDuration(relativeTo: relativeNow), "8h")
    }

    func testFastObjectWillChangeFiresOnMutation() {
        let fast = Fast(context: context)
        fast.id = UUID()
        let start = Date(timeIntervalSince1970: 100000)
        fast.startDate = start
        fast.endDate = start.addingTimeInterval(12 * 3600)
        fast.targetDuration = 16 * 3600

        var changeFired = false
        fast.objectWillChange
            .sink { _ in
                changeFired = true
            }
            .store(in: &cancellables)

        // Mutating endDate simulates the FastDetailView edit
        fast.endDate = start.addingTimeInterval(18 * 3600)
        context.processPendingChanges()

        XCTAssertTrue(
            changeFired,
            "Editing properties on Fast must fire objectWillChange to notify ObservedObject views"
        )
        XCTAssertEqual(fast.formattedDuration, "18h")
        XCTAssertTrue(fast.isGoalMet)
    }
}
