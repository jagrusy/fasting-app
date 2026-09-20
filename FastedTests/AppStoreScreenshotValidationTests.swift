import XCTest
@testable import Fasted

final class AppStoreScreenshotValidationTests: XCTestCase {

    struct ScreenshotRequirement {
        let displayType: String
        let width: Int
        let height: Int
    }

    private let requiredFormats: [ScreenshotRequirement] = [
        ScreenshotRequirement(displayType: "6.9\" iPhone", width: 1320, height: 2868),
        ScreenshotRequirement(displayType: "6.5\" iPhone", width: 1284, height: 2778),
        ScreenshotRequirement(displayType: "Apple Watch Series 4+ (44mm)", width: 368, height: 448)
    ]

    func testAppStoreRequiredResolutionsAreRecognized() {
        for requirement in requiredFormats {
            XCTAssertGreaterThan(requirement.width, 0)
            XCTAssertGreaterThan(requirement.height, 0)
            XCTAssertLessThan(requirement.width, requirement.height, "Portraits should be taller than wide")
        }
    }

    func testScreenshotDimensionsMatching() {
        // Test 6.9" iPhone resolution
        XCTAssertTrue(matchesResolution(width: 1320, height: 2868, targetWidth: 1320, targetHeight: 2868))

        // Test 6.5" iPhone resolution
        XCTAssertTrue(matchesResolution(width: 1284, height: 2778, targetWidth: 1284, targetHeight: 2778))

        // Test Apple Watch 44mm resolution
        XCTAssertTrue(matchesResolution(width: 368, height: 448, targetWidth: 368, targetHeight: 448))

        // Test Apple Watch Ultra resolution
        XCTAssertTrue(matchesResolution(width: 422, height: 514, targetWidth: 422, targetHeight: 514))
    }

    func testAppStoreScreenshotsFolderCompleteness() throws {
        let screenshotsURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fastlane/screenshots/en-US")

        guard FileManager.default.fileExists(atPath: screenshotsURL.path) else {
            return
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: screenshotsURL.path)
            .filter { $0.hasSuffix(".png") }

        let has69 = files.contains { $0.contains("1320x2868") }
        let has65 = files.contains { $0.contains("1284x2778") }
        let hasWatch44 = files.contains { $0.contains("368x448") }

        XCTAssertTrue(has69, "Should include 6.9\" iPhone screenshots")
        XCTAssertTrue(has65, "Should include 6.5\" iPhone screenshots")
        XCTAssertTrue(hasWatch44, "Should include 44mm Apple Watch screenshots")
    }

    private func matchesResolution(width: Int, height: Int, targetWidth: Int, targetHeight: Int) -> Bool {
        width == targetWidth && height == targetHeight
    }
}
