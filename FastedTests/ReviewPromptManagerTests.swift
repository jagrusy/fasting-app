import XCTest
import CoreData
@testable import Fasted

@MainActor
final class ReviewPromptManagerTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var testUserDefaults: UserDefaults!
    private var reviewManager: ReviewPromptManager!

    override func setUp() {
        super.setUp()
        let container = NSPersistentContainer(name: "Fasted")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, _ in }
        context = container.viewContext

        testUserDefaults = UserDefaults(suiteName: "ReviewPromptTestsSuite")
        testUserDefaults.removePersistentDomain(forName: "ReviewPromptTestsSuite")

        reviewManager = ReviewPromptManager(userDefaults: testUserDefaults)
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "ReviewPromptTestsSuite")
        super.tearDown()
    }

    private func createFast(isCompleted: Bool, dayOffset: Int = 0) -> Fast {
        let fast = Fast(context: context)
        fast.id = UUID()
        let start = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
        fast.startDate = start
        fast.endDate = start.addingTimeInterval(16 * 3600)
        fast.targetDuration = 16 * 3600
        fast.isCompleted = isCompleted
        fast.protocolType = "16:8"
        return fast
    }

    func testNotEligibleIfFastNotCompleted() throws {
        let uncompleted = createFast(isCompleted: false)
        let eligible = reviewManager.isEligibleForReviewPrompt(
            completedFast: uncompleted,
            allCompletedFasts: [uncompleted]
        )
        XCTAssertFalse(eligible)
    }

    func testEligibleOnThirdCompletedFast() throws {
        let fast1 = createFast(isCompleted: true, dayOffset: 2)
        let fast2 = createFast(isCompleted: true, dayOffset: 1)
        let fast3 = createFast(isCompleted: true, dayOffset: 0)

        let eligible = reviewManager.isEligibleForReviewPrompt(
            completedFast: fast3,
            allCompletedFasts: [fast1, fast2, fast3]
        )
        XCTAssertTrue(eligible)
    }

    func testNotEligibleOnFirstOrSecondFast() throws {
        let fast1 = createFast(isCompleted: true, dayOffset: 1)
        let fast2 = createFast(isCompleted: true, dayOffset: 0)

        let eligible1 = reviewManager.isEligibleForReviewPrompt(
            completedFast: fast1,
            allCompletedFasts: [fast1]
        )
        let eligible2 = reviewManager.isEligibleForReviewPrompt(
            completedFast: fast2,
            allCompletedFasts: [fast1, fast2]
        )

        XCTAssertFalse(eligible1)
        XCTAssertFalse(eligible2)
    }

    func testCooldownPeriodPreventsPromptWithin60Days() throws {
        let fast1 = createFast(isCompleted: true, dayOffset: 2)
        let fast2 = createFast(isCompleted: true, dayOffset: 1)
        let fast3 = createFast(isCompleted: true, dayOffset: 0)

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        testUserDefaults.set(thirtyDaysAgo, forKey: ReviewPromptManager.lastPromptDateKey)

        let eligible = reviewManager.isEligibleForReviewPrompt(
            completedFast: fast3,
            allCompletedFasts: [fast1, fast2, fast3]
        )
        XCTAssertFalse(eligible)
    }
}
