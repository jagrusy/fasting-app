import XCTest
import CoreData
@testable import Fasted

@MainActor
final class FastManagerValidationTests: XCTestCase {
    var persistenceController: PersistenceController?
    var context: NSManagedObjectContext?
    var fastManager: FastManager?
    var testDefaults: UserDefaults?
    var testDefaultsSuiteName: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let suiteName = "FastManagerValidationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.persistenceController = controller
        self.context = ctx
        self.testDefaultsSuiteName = suiteName
        self.testDefaults = defaults
        self.fastManager = FastManager(context: ctx, defaults: defaults)
    }

    override func tearDownWithError() throws {
        fastManager = nil
        persistenceController = nil
        context = nil
        if let suiteName = testDefaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        testDefaultsSuiteName = nil
        try super.tearDownWithError()
    }

    func testValidateIntervalRejectsFutureDates() throws {
        let manager = try XCTUnwrap(fastManager)
        let futureStart = Date().addingTimeInterval(3600)
        let validation = manager.validateInterval(startDate: futureStart)
        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.message, "Start time cannot be in the future.")

        let pastStart = Date().addingTimeInterval(-7200)
        let futureEnd = Date().addingTimeInterval(1800)
        let endValidation = manager.validateInterval(startDate: pastStart, endDate: futureEnd)
        XCTAssertFalse(endValidation.isValid)
        XCTAssertEqual(endValidation.message, "End time cannot be in the future.")
    }

    func testValidateIntervalDetectsOverlap() throws {
        let manager = try XCTUnwrap(fastManager)
        let now = Date()
        let fast1Start = now.addingTimeInterval(-86400)
        let fast1End = now.addingTimeInterval(-43200)

        let fast1 = manager.startFast(startDate: fast1Start, targetDuration: 16 * 3600)
        manager.endFast(endDate: fast1End)

        // Attempt overlapping interval
        let overlapStart = now.addingTimeInterval(-64800)
        let overlapEnd = now.addingTimeInterval(-21600)
        let overlapValidation = manager.validateInterval(startDate: overlapStart, endDate: overlapEnd)
        XCTAssertFalse(overlapValidation.isValid)
        XCTAssertTrue(overlapValidation.message?.contains("overlaps") == true)

        // Valid non-overlapping interval
        let validStart = now.addingTimeInterval(-36000)
        let validEnd = now.addingTimeInterval(-7200)
        let validValidation = manager.validateInterval(startDate: validStart, endDate: validEnd)
        XCTAssertTrue(validValidation.isValid)

        // Self-exclusion test
        let selfValidation = manager.validateInterval(
            startDate: fast1Start,
            endDate: fast1End,
            excludingFastId: fast1.id
        )
        XCTAssertTrue(selfValidation.isValid)
    }

    func testClearAllFastingData() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        _ = manager.startFast(startDate: Date().addingTimeInterval(-3600))
        manager.endFast(endDate: Date())
        _ = manager.startFast(startDate: Date())

        XCTAssertTrue(manager.isFasting)

        manager.clearAllFastingData()

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let count = try ctx.count(for: request)
        XCTAssertEqual(count, 0)
    }
}
