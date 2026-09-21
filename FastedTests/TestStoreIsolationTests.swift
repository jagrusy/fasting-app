import XCTest
import CoreData
@testable import Fasted

@MainActor
final class TestStoreIsolationTests: XCTestCase {
    private var tempDirectory: URL?
    private var controllers: [PersistenceController] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        controllers.removeAll()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "TestStoreIsolation_\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectory = dir
    }

    override func tearDownWithError() throws {
        for controller in controllers {
            let coordinator = controller.container.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        controllers.removeAll()

        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    private func makeController(storeURL: URL) -> PersistenceController {
        let controller = PersistenceController(storeURL: storeURL)
        controllers.append(controller)
        return controller
    }

    func testIsolatedDiskStoreCreatesSeparateFileAndPersists() throws {
        guard let tempDirectory = tempDirectory else {
            XCTFail("tempDirectory must be initialized")
            return
        }
        let storeURL = tempDirectory.appendingPathComponent("isolated_store_1.sqlite")
        let fastId = UUID()

        // Phase 1: Write fast to isolated store
        do {
            let controller = makeController(storeURL: storeURL)
            let context = controller.container.viewContext

            let fast = Fast(context: context)
            fast.id = fastId
            fast.startDate = Date().addingTimeInterval(-3600)
            fast.endDate = Date()
            fast.targetDuration = 16 * 3600
            fast.protocolType = "16:8"
            fast.isCompleted = true
            fast.createdAt = fast.startDate
            fast.updatedAt = fast.endDate

            try context.save()
            XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        }

        // Phase 2: Reopen a fresh PersistenceController pointing to the exact same storeURL
        do {
            let reopenedController = makeController(storeURL: storeURL)
            let reopenedContext = reopenedController.container.viewContext

            let fetchRequest: NSFetchRequest<Fast> = Fast.fetchRequest()
            let results = try reopenedContext.fetch(fetchRequest)

            XCTAssertEqual(results.count, 1, "Reopened store must contain the persisted fast")
            XCTAssertEqual(results.first?.id, fastId, "Persisted fast UUID must match exactly across reloads")
            XCTAssertEqual(results.first?.protocolType, "16:8")
            XCTAssertEqual(results.first?.isCompleted, true)
        }
    }

    func testIsolatedStoresDoNotCrossPollute() throws {
        guard let tempDirectory = tempDirectory else {
            XCTFail("tempDirectory must be initialized")
            return
        }
        let storeURLA = tempDirectory.appendingPathComponent("isolated_store_A.sqlite")
        let storeURLB = tempDirectory.appendingPathComponent("isolated_store_B.sqlite")

        let controllerA = makeController(storeURL: storeURLA)
        let controllerB = makeController(storeURL: storeURLB)

        // Write fast only to Store A
        let fastA = Fast(context: controllerA.container.viewContext)
        let now = Date()
        fastA.id = UUID()
        fastA.startDate = now
        fastA.targetDuration = 16 * 3600
        fastA.protocolType = "16:8"
        fastA.isCompleted = false
        fastA.createdAt = now
        fastA.updatedAt = now
        try controllerA.container.viewContext.save()

        // Verify Store A has 1 fast, Store B has 0 fasts
        let fetchA: NSFetchRequest<Fast> = Fast.fetchRequest()
        let fetchB: NSFetchRequest<Fast> = Fast.fetchRequest()

        let resultsA = try controllerA.container.viewContext.fetch(fetchA)
        let resultsB = try controllerB.container.viewContext.fetch(fetchB)

        XCTAssertEqual(resultsA.count, 1, "Store A must have 1 fast")
        XCTAssertEqual(resultsB.count, 0, "Store B must be completely isolated and remain empty")
    }

    func testFastManagerStartsAndCommitsFastWithDeniedNotifications() throws {
        guard let tempDirectory = tempDirectory else {
            XCTFail("tempDirectory must be initialized")
            return
        }
        let storeURL = tempDirectory.appendingPathComponent("denied_notifications.sqlite")
        let controller = makeController(storeURL: storeURL)
        let suiteName = "TestStoreIsolationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let manager = FastManager(context: controller.container.viewContext, defaults: defaults)

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        // Simulate starting fast even if notifications are denied or disabled
        let startDate = Date()
        manager.startFast(startDate: startDate, targetDuration: 16 * 3600, protocolType: "16:8")

        // Assert state is committed and active
        XCTAssertTrue(manager.isFasting, "FastManager must report isFasting = true")
        XCTAssertNotNil(manager.activeFast, "FastManager activeFast must be non-nil")
        XCTAssertEqual(manager.activeFast?.protocolType, "16:8")

        // Verify committed in store directly
        let fetchRequest: NSFetchRequest<Fast> = Fast.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == NO")
        let activeFasts = try controller.container.viewContext.fetch(fetchRequest)
        XCTAssertEqual(activeFasts.count, 1, "Active fast must be durably committed in Core Data")
    }

    #if DEBUG
    func testMockDataSeedingInIsolatedStoreOnly() throws {
        guard let tempDirectory = tempDirectory else {
            XCTFail("tempDirectory must be initialized")
            return
        }
        let storeURL = tempDirectory.appendingPathComponent("screenshot_seed.sqlite")
        let controller = makeController(storeURL: storeURL)
        let suiteName = "TestScreenshotSeed.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let manager = FastManager(context: controller.container.viewContext, defaults: defaults)
        manager.seedMockDataForScreenshots(progress: 0.8)

        let fetchCompleted: NSFetchRequest<Fast> = Fast.fetchRequest()
        fetchCompleted.predicate = NSPredicate(format: "isCompleted == YES")
        let completedFasts = try controller.container.viewContext.fetch(fetchCompleted)

        let fetchActive: NSFetchRequest<Fast> = Fast.fetchRequest()
        fetchActive.predicate = NSPredicate(format: "isCompleted == NO")
        let activeFasts = try controller.container.viewContext.fetch(fetchActive)

        XCTAssertEqual(completedFasts.count, 14, "Seeding must create 14 days of streak history in isolated store")
        XCTAssertEqual(activeFasts.count, 1, "Seeding must create 1 active fast in isolated store")
    }
    #endif
}
