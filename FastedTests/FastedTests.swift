import XCTest
import CoreData
@testable import Fasted

@MainActor
final class FastedTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var fastManager: FastManager?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        self.persistenceController = controller
        self.context = ctx
        self.fastManager = FastManager(context: ctx)
    }

    override func tearDownWithError() throws {
        fastManager = nil
        persistenceController = nil
        context = nil
        try super.tearDownWithError()
    }

    func testCoreDataStackInitialization() throws {
        XCTAssertNotNil(persistenceController)
        XCTAssertNotNil(context)
    }

    func testFastingProtocolPresets() {
        XCTAssertEqual(FastingProtocol.presets.count, 6)
        XCTAssertEqual(FastingProtocol.default.ratioString, "16:8")
        XCTAssertEqual(FastingProtocol.default.fastingSeconds, 57600.0)

        let warrior = FastingProtocol.from(protocolType: "20:4")
        XCTAssertEqual(warrior.name, "Warrior")
        XCTAssertEqual(warrior.fastingHours, 20)
        XCTAssertEqual(warrior.eatingHours, 4)

        let fallback = FastingProtocol.from(protocolType: "unknown")
        XCTAssertEqual(fallback.ratioString, "16:8")
    }

    func testFastManagerStartsAndEndsFast() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        let startTime = Date().addingTimeInterval(-1000)
        let fast = manager.startFast(startDate: startTime, targetDuration: 57600, protocolType: "16:8")

        XCTAssertTrue(manager.isFasting)
        XCTAssertNotNil(manager.activeFast)
        XCTAssertEqual(manager.activeFast?.id, fast.id)
        XCTAssertEqual(manager.activeFast?.protocolType, "16:8")

        // Ending fast
        let endTime = Date()
        manager.endFast(endDate: endTime, moodRating: 4)

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        // Verify stored in Core Data
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try ctx.fetch(request)
        XCTAssertEqual(results.count, 1)
        let saved = try XCTUnwrap(results.first)
        XCTAssertEqual(saved.id, fast.id)
        XCTAssertEqual(saved.endDate, endTime)
        XCTAssertEqual(saved.moodRating, 4)
    }

    func testFastManagerPreventsDuplicateActiveFasts() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        let first = manager.startFast(startDate: Date())
        let second = manager.startFast(startDate: Date().addingTimeInterval(10))

        XCTAssertEqual(first.id, second.id)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try ctx.fetch(request)
        XCTAssertEqual(results.count, 1)
    }

    func testFastManagerUpdatesActiveFast() throws {
        let manager = try XCTUnwrap(fastManager)
        _ = manager.startFast(startDate: Date(), targetDuration: 57600)
        let newStartDate = Date().addingTimeInterval(-3600)
        let newDuration: TimeInterval = 18 * 3600

        manager.updateActiveFast(startDate: newStartDate, targetDuration: newDuration)

        XCTAssertEqual(manager.activeFast?.startDate, newStartDate)
        XCTAssertEqual(manager.activeFast?.targetDuration, newDuration)
    }

    func testPreviewPersistenceController() throws {
        let preview = PersistenceController.preview
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try preview.container.viewContext.fetch(request)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }
}
