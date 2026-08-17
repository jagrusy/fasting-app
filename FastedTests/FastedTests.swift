import XCTest
import CoreData
import CoreGraphics
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

    func testFastManagerDeletesFast() throws {
        let manager = try XCTUnwrap(fastManager)
        let ctx = try XCTUnwrap(context)

        let fast = manager.startFast(startDate: Date())
        XCTAssertTrue(manager.isFasting)

        manager.deleteFast(fast)
        XCTAssertFalse(manager.isFasting)

        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try ctx.fetch(request)
        XCTAssertEqual(results.count, 0)
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

    // MARK: - Dial Math Unit Tests

    func testDialMathAngleConversions() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // 12:00 AM = 0°
        var components = DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        var testDate = calendar.date(from: components) ?? Date()
        XCTAssertEqual(DialMath.angle(for: testDate, calendar: calendar), 0.0, accuracy: 0.1)

        // 6:00 AM = 90°
        components.hour = 6
        testDate = calendar.date(from: components) ?? Date()
        XCTAssertEqual(DialMath.angle(for: testDate, calendar: calendar), 90.0, accuracy: 0.1)

        // 12:00 PM (Noon) = 180°
        components.hour = 12
        testDate = calendar.date(from: components) ?? Date()
        XCTAssertEqual(DialMath.angle(for: testDate, calendar: calendar), 180.0, accuracy: 0.1)

        // 6:00 PM = 270°
        components.hour = 18
        testDate = calendar.date(from: components) ?? Date()
        XCTAssertEqual(DialMath.angle(for: testDate, calendar: calendar), 270.0, accuracy: 0.1)
    }

    func testDialMathDateFromAngleAndSnapping() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0)) ?? Date()

        // 90° -> 6:00 AM
        let date6AM = DialMath.date(from: 90.0, baseDate: baseDate, calendar: calendar, snapToMinutes: 5)
        XCTAssertEqual(calendar.component(.hour, from: date6AM), 6)
        XCTAssertEqual(calendar.component(.minute, from: date6AM), 0)

        // 182.5° -> 12:10 PM snapped to 5-minute increment
        let dateNoonSnapped = DialMath.date(from: 182.5, baseDate: baseDate, calendar: calendar, snapToMinutes: 5)
        XCTAssertEqual(calendar.component(.hour, from: dateNoonSnapped), 12)
        XCTAssertEqual(calendar.component(.minute, from: dateNoonSnapped), 10)
    }

    func testDialMathTouchAngles() {
        let center = CGPoint(x: 100, y: 100)

        // Top (12 o'clock) -> 0°
        let topPoint = CGPoint(x: 100, y: 50)
        XCTAssertEqual(DialMath.touchAngle(point: topPoint, center: center), 0.0, accuracy: 0.1)

        // Right (3 o'clock / 6 AM on dial) -> 90°
        let rightPoint = CGPoint(x: 150, y: 100)
        XCTAssertEqual(DialMath.touchAngle(point: rightPoint, center: center), 90.0, accuracy: 0.1)

        // Bottom (6 o'clock / 12 PM on dial) -> 180°
        let bottomPoint = CGPoint(x: 100, y: 150)
        XCTAssertEqual(DialMath.touchAngle(point: bottomPoint, center: center), 180.0, accuracy: 0.1)

        // Left (9 o'clock / 6 PM on dial) -> 270°
        let leftPoint = CGPoint(x: 50, y: 100)
        XCTAssertEqual(DialMath.touchAngle(point: leftPoint, center: center), 270.0, accuracy: 0.1)
    }

    func testDialMathSweepAndMidnightCrossing() {
        // Simple day window: 12 PM (180°) to 8 PM (300°) -> 120° sweep = 8 hours
        let sweepDay = DialMath.sweepAngle(from: 180.0, to: 300.0)
        XCTAssertEqual(sweepDay, 120.0, accuracy: 0.1)
        XCTAssertEqual(DialMath.computeDuration(startAngle: 180.0, endAngle: 300.0), 8 * 3600, accuracy: 1.0)

        // Midnight-crossing window: 8 PM (300°) to 12 PM next day (180°) -> 240° sweep = 16 hours
        let sweepMidnight = DialMath.sweepAngle(from: 300.0, to: 180.0)
        XCTAssertEqual(sweepMidnight, 240.0, accuracy: 0.1)
        XCTAssertEqual(DialMath.computeDuration(startAngle: 300.0, endAngle: 180.0), 16 * 3600, accuracy: 1.0)

        // isAngle checks for midnight crossing
        XCTAssertTrue(DialMath.isAngle(330.0, between: 300.0, and: 180.0)) // 10 PM is inside
        XCTAssertTrue(DialMath.isAngle(90.0, between: 300.0, and: 180.0))  // 6 AM is inside
        XCTAssertFalse(DialMath.isAngle(240.0, between: 300.0, and: 180.0)) // 4 PM is outside
    }

    func testPreviewPersistenceController() throws {
        let preview = PersistenceController.preview
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        let results = try preview.container.viewContext.fetch(request)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }
}
