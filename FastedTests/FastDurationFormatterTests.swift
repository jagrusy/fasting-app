import XCTest
@testable import Fasted

final class FastDurationFormatterTests: XCTestCase {
    func testFormatDurationZero() {
        XCTAssertEqual(FastDurationFormatter.formatDuration(0), "0m")
    }

    func testFormatDurationNegative() {
        XCTAssertEqual(FastDurationFormatter.formatDuration(-120), "0m")
    }

    func testFormatDurationMinutesOnly() {
        XCTAssertEqual(FastDurationFormatter.formatDuration(45 * 60), "45m")
        XCTAssertEqual(FastDurationFormatter.formatDuration(59 * 60 + 50), "59m")
    }

    func testFormatDurationHoursOnly() {
        XCTAssertEqual(FastDurationFormatter.formatDuration(16 * 3600), "16h")
        XCTAssertEqual(FastDurationFormatter.formatDuration(1 * 3600), "1h")
    }

    func testFormatDurationHoursAndMinutes() {
        XCTAssertEqual(FastDurationFormatter.formatDuration(16 * 3600 + 24 * 60), "16h 24m")
        XCTAssertEqual(FastDurationFormatter.formatDuration(2 * 3600 + 5 * 60), "2h 5m")
    }

    func testFormatClock() {
        XCTAssertEqual(FastDurationFormatter.formatClock(0), "00:00:00")
        XCTAssertEqual(FastDurationFormatter.formatClock(59), "00:00:59")
        XCTAssertEqual(FastDurationFormatter.formatClock(15 * 60 + 32), "00:15:32")
        XCTAssertEqual(FastDurationFormatter.formatClock(16 * 3600 + 24 * 60 + 5), "16:24:05")
    }

    func testFormatTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 14
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components) ?? Date()

        let timeStr = FastDurationFormatter.formatTime(date)
        XCTAssertFalse(timeStr.isEmpty)
    }

    func testFormatDateRange() {
        var startComponents = DateComponents()
        startComponents.year = 2026
        startComponents.month = 9
        startComponents.day = 14
        startComponents.hour = 8
        startComponents.minute = 0
        let start = Calendar.current.date(from: startComponents) ?? Date()

        var endComponents = DateComponents()
        endComponents.year = 2026
        endComponents.month = 9
        endComponents.day = 14
        endComponents.hour = 12
        endComponents.minute = 0
        let end = Calendar.current.date(from: endComponents) ?? Date()

        let rangeStr = FastDurationFormatter.formatDateRange(start: start, end: end)
        XCTAssertTrue(rangeStr.contains("·"))
        XCTAssertTrue(rangeStr.contains("–"))
    }
}
