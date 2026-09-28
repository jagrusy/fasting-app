import CoreData
import XCTest
@testable import Fasted

@MainActor
final class MealManagerTests: XCTestCase {
    private var container: NSPersistentContainer?
    private var photoStorage: MealPhotoStorage?
    private var preferences: JournalPreferences?
    private var tempDirectory: URL?
    private var testUserDefaults: UserDefaults?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meal_manager_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirectory = tempDir
        photoStorage = MealPhotoStorage(directoryURL: tempDir)

        let model = PersistenceController.shared.container.managedObjectModel
        let persistentContainer = NSPersistentContainer(name: "Fasted", managedObjectModel: model)
        persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        container = persistentContainer

        let userDefaults = UserDefaults(suiteName: "meal_manager_test_suite_\(UUID().uuidString)")
        testUserDefaults = userDefaults
        if let userDefaults {
            preferences = JournalPreferences(userDefaults: userDefaults)
        }
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        if let testUserDefaults {
            testUserDefaults.removePersistentDomain(forName: testUserDefaults.description)
        }
        container = nil
        photoStorage = nil
        preferences = nil
        testUserDefaults = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }

    private func makeManager() throws -> (MealManager, NSPersistentContainer) {
        let currentContainer = try XCTUnwrap(container)
        let currentPreferences = try XCTUnwrap(preferences)
        let currentPhotoStorage = try XCTUnwrap(photoStorage)
        let manager = MealManager(
            coordinator: currentContainer.persistentStoreCoordinator,
            preferences: currentPreferences,
            photoStorage: currentPhotoStorage
        )
        return (manager, currentContainer)
    }

    func testPostFastInvitationTriggerOnlyWhenEnabled() throws {
        let (manager, _) = try makeManager()

        // Initially disabled
        manager.handleFastEnded(endDate: Date())
        XCTAssertFalse(manager.showPostFastComposer)

        // Enable journal only
        manager.isJournalEnabled = true
        manager.handleFastEnded(endDate: Date())
        XCTAssertFalse(manager.showPostFastComposer)

        // Enable post fast prompt
        manager.postFastPromptEnabled = true
        let endDate = Date()
        manager.handleFastEnded(endDate: endDate)
        XCTAssertTrue(manager.showPostFastComposer)
        XCTAssertEqual(manager.postFastComposerMealTime, endDate)
    }

    func testDeclinePostFastPromptPermanently() throws {
        let (manager, _) = try makeManager()
        manager.isJournalEnabled = true
        manager.postFastPromptEnabled = true

        manager.declinePostFastPromptPermanently()
        XCTAssertTrue(manager.hasDeclinedPostFastPromptPermanently)
        XCTAssertFalse(manager.postFastPromptEnabled)
        XCTAssertFalse(manager.showPostFastComposer)

        // Ending another fast should not trigger composer
        manager.handleFastEnded(endDate: Date())
        XCTAssertFalse(manager.showPostFastComposer)
    }

    func testSaveMealDuringActiveFastTriggersConfirmation() throws {
        let (manager, currentContainer) = try makeManager()

        let fastContext = currentContainer.viewContext
        let fast = Fast(context: fastContext)
        fast.id = UUID()
        let startDate = Date().addingTimeInterval(-3600)
        fast.startDate = startDate // 1 hour ago
        fast.targetDuration = 16 * 3600
        fast.isCompleted = false
        fast.protocolType = "16:8"
        fast.createdAt = startDate
        fast.updatedAt = Date()

        // Meal eaten 30 mins ago falls within active fast
        let mealDate = Date().addingTimeInterval(-1800)
        let draft = MealDraft(mealTime: mealDate, notes: "Snack during fast")

        let meal = try manager.saveMeal(draft: draft, activeFast: fast)
        XCTAssertEqual(meal.notes, "Snack during fast")
        XCTAssertNotNil(manager.fastingOverlapConfirmation)
        XCTAssertEqual(manager.fastingOverlapConfirmation?.activeFastId, fast.id)
    }

    func testSaveMealOutsideActiveFastDoesNotTriggerConfirmation() throws {
        let (manager, currentContainer) = try makeManager()

        let fastContext = currentContainer.viewContext
        let fast = Fast(context: fastContext)
        fast.id = UUID()
        let startDate = Date().addingTimeInterval(-3600)
        fast.startDate = startDate // 1 hour ago
        fast.targetDuration = 16 * 3600
        fast.isCompleted = false
        fast.protocolType = "16:8"
        fast.createdAt = startDate
        fast.updatedAt = Date()

        // Meal eaten 2 hours ago is before active fast started
        let mealDate = Date().addingTimeInterval(-7200)
        let draft = MealDraft(mealTime: mealDate, notes: "Pre-fast meal")

        _ = try manager.saveMeal(draft: draft, activeFast: fast)
        XCTAssertNil(manager.fastingOverlapConfirmation)
    }
}
