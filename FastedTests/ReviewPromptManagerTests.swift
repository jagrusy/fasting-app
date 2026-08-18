import XCTest
import CoreData
@testable import Fasted

@MainActor
final class ReviewPromptManagerTests: XCTestCase {

    private func createTestContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "Fasted")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    private func createFast(context: NSManagedObjectContext, isCompleted: Bool, dayOffset: Int = 0) -> Fast {
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
        let context = createTestContext()
        let defaults = UserDefaults(suiteName: "ReviewPromptTest1") ?? .standard
        let reviewManager = ReviewPromptManager(userDefaults: defaults)

        let uncompleted = createFast(context: context, isCompleted: false)
        let eligible = reviewManager.isEligibleForReviewPrompt(
            completedFast: uncompleted,
            allCompletedFasts: [uncompleted]
        )
        XCTAssertFalse(eligible)
    }

    func testEligibleOnThirdCompletedFast() throws {
        let context = createTestContext()
        let defaults = UserDefaults(suiteName: "ReviewPromptTest2") ?? .standard
        defaults.removePersistentDomain(forName: "ReviewPromptTest2")
        let reviewManager = ReviewPromptManager(userDefaults: defaults)

        let fast1 = createFast(context: context, isCompleted: true, dayOffset: 2)
        let fast2 = createFast(context: context, isCompleted: true, dayOffset: 1)
        let fast3 = createFast(context: context, isCompleted: true, dayOffset: 0)

        let eligible = reviewManager.isEligibleForReviewPrompt(
            completedFast: fast3,
            allCompletedFasts: [fast1, fast2, fast3]
        )
        XCTAssertTrue(eligible)
    }

    func testNotEligibleOnFirstOrSecondFast() throws {
        let context = createTestContext()
        let defaults = UserDefaults(suiteName: "ReviewPromptTest3") ?? .standard
        defaults.removePersistentDomain(forName: "ReviewPromptTest3")
        let reviewManager = ReviewPromptManager(userDefaults: defaults)

        let fast1 = createFast(context: context, isCompleted: true, dayOffset: 1)
        let fast2 = createFast(context: context, isCompleted: true, dayOffset: 0)

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
        let context = createTestContext()
        let suiteName = "ReviewPromptTest4"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        defaults.set(thirtyDaysAgo, forKey: ReviewPromptManager.lastPromptDateKey)

        let reviewManager = ReviewPromptManager(userDefaults: defaults)

        let fast1 = createFast(context: context, isCompleted: true, dayOffset: 2)
        let fast2 = createFast(context: context, isCompleted: true, dayOffset: 1)
        let fast3 = createFast(context: context, isCompleted: true, dayOffset: 0)

        let eligible = reviewManager.isEligibleForReviewPrompt(
            completedFast: fast3,
            allCompletedFasts: [fast1, fast2, fast3]
        )
        XCTAssertFalse(eligible)
    }
}
