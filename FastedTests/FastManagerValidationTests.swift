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
    var testCoordinator: AppGroupCoordinator?
    var tempCommandsDir: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let suiteName = "FastManagerValidationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let commandsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        let coord = AppGroupCoordinator(
            userDefaults: defaults,
            appGroupId: suiteName,
            commandsDirectory: commandsDir
        )
        self.persistenceController = controller
        self.context = ctx
        self.testDefaultsSuiteName = suiteName
        self.testDefaults = defaults
        self.tempCommandsDir = commandsDir
        self.testCoordinator = coord
        self.fastManager = FastManager(context: ctx, defaults: defaults, coordinator: coord)
    }

    override func tearDownWithError() throws {
        fastManager = nil
        persistenceController = nil
        context = nil
        testCoordinator = nil
        if let suiteName = testDefaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        if let dir = tempCommandsDir {
            try? FileManager.default.removeItem(at: dir)
        }
        tempCommandsDir = nil
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

        let fast1 = try XCTUnwrap(manager.startFast(startDate: fast1Start, targetDuration: 16 * 3600))
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
        let coord = try XCTUnwrap(testCoordinator)

        _ = manager.startFast(startDate: Date().addingTimeInterval(-3600))
        manager.endFast(endDate: Date())
        _ = manager.startFast(startDate: Date())
        coord.enqueueCommand(.snoozeFast(extensionSeconds: 1800))

        XCTAssertTrue(manager.isFasting)
        XCTAssertTrue(coord.readSnapshot().isFasting)

        manager.clearAllFastingData()

        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.activeFast)
        XCTAssertFalse(coord.readSnapshot().isFasting)
        XCTAssertTrue(coord.drainPendingCommands().isEmpty)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let count = try ctx.count(for: request)
        XCTAssertEqual(count, 0)
    }
}
