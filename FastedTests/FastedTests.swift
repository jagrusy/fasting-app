import XCTest
import CoreData
@testable import Fasted

final class FastedTests: XCTestCase {
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        try super.tearDownWithError()
    }

    func testCoreDataStackInitialization() throws {
        XCTAssertNotNil(persistenceController)
        XCTAssertNotNil(context)
    }

    func testCreateAndFetchFastEntity() throws {
        let fast = Fast(context: context)
        let fastId = UUID()
        let startDate = Date()
        let targetDuration: TimeInterval = 16 * 3600

        fast.id = fastId
        fast.startDate = startDate
        fast.targetDuration = targetDuration
        fast.protocolType = "16:8"
        fast.isCompleted = false
        fast.createdAt = startDate
        fast.updatedAt = startDate

        try context.save()

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", fastId as CVarArg)

        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
        let fetched = try XCTUnwrap(results.first)
        XCTAssertEqual(fetched.id, fastId)
        XCTAssertEqual(fetched.protocolType, "16:8")
        XCTAssertEqual(fetched.targetDuration, 57600.0)
        XCTAssertFalse(fetched.isCompleted)
        XCTAssertNil(fetched.endDate)
    }

    func testCreateAndFetchUserSettingsEntity() throws {
        let settings = UserSettings(context: context)
        let settingsId = UUID()

        settings.id = settingsId
        settings.selectedProtocol = "18:6"
        settings.notificationsEnabled = true

        try context.save()

        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", settingsId as CVarArg)

        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
        let fetched = try XCTUnwrap(results.first)
        XCTAssertEqual(fetched.id, settingsId)
        XCTAssertEqual(fetched.selectedProtocol, "18:6")
        XCTAssertTrue(fetched.notificationsEnabled)
    }

    func testPreviewPersistenceController() throws {
        let preview = PersistenceController.preview
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try preview.container.viewContext.fetch(request)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }
}
