import XCTest
import CoreGraphics
@testable import Fasted

final class FastedDialMathTests: XCTestCase {

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
        let sweepDay = DialMath.sweepAngle(from: 180.0, to: 300.0)
        XCTAssertEqual(sweepDay, 120.0, accuracy: 0.1)
        XCTAssertEqual(DialMath.computeDuration(startAngle: 180.0, endAngle: 300.0), 8 * 3600, accuracy: 1.0)

        let sweepMidnight = DialMath.sweepAngle(from: 300.0, to: 180.0)
        XCTAssertEqual(sweepMidnight, 240.0, accuracy: 0.1)
        XCTAssertEqual(DialMath.computeDuration(startAngle: 300.0, endAngle: 180.0), 16 * 3600, accuracy: 1.0)

        XCTAssertTrue(DialMath.isAngle(330.0, between: 300.0, and: 180.0))
        XCTAssertTrue(DialMath.isAngle(90.0, between: 300.0, and: 180.0))
        XCTAssertFalse(DialMath.isAngle(240.0, between: 300.0, and: 180.0))
    }

    func testSnapIntervalRoundsToNearestFiveMinutes() {
        XCTAssertEqual(DialMath.snapInterval(0, toMinutes: 5), 0)
        XCTAssertEqual(DialMath.snapInterval(60, toMinutes: 5), 0) // rounds down to nearest 5 min
        XCTAssertEqual(DialMath.snapInterval(150, toMinutes: 5), 300) // 2:30 rounds up
        XCTAssertEqual(DialMath.snapInterval(299, toMinutes: 5), 300)
        XCTAssertEqual(DialMath.snapInterval(301, toMinutes: 5), 300)
        XCTAssertEqual(DialMath.snapInterval(16 * 3600 + 61, toMinutes: 5), 16 * 3600, accuracy: 0.1)

        // Never returns a negative duration
        XCTAssertEqual(DialMath.snapInterval(-100, toMinutes: 5), 0)
    }
}
