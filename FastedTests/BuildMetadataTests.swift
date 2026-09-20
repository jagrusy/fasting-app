import XCTest
import Fasted

final class BuildMetadataTests: XCTestCase {

    func testMarketingVersionFormat() {
        let version = BuildMetadata.marketingVersion
        XCTAssertFalse(version.isEmpty, "Marketing version must not be empty")

        // Must consist only of numbers and periods (Apple requirement)
        let components = version.split(separator: ".")
        XCTAssertGreaterThanOrEqual(components.count, 2, "Version must have at least major and minor")
        XCTAssertLessThanOrEqual(components.count, 3, "Version must have at most 3 components")

        for component in components {
            XCTAssertNotNil(Int(component), "Each version component must be numeric: \(component)")
        }
    }

    func testGitCommitPresence() {
        let commit = BuildMetadata.gitCommit
        XCTAssertFalse(commit.isEmpty, "Git commit must not be empty")
    }

    func testBuildDateFormat() {
        let dateString = BuildMetadata.buildDate
        XCTAssertFalse(dateString.isEmpty, "Build date must not be empty")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        XCTAssertNotNil(formatter.date(from: dateString), "Build date must be in yyyy-MM-dd format")
    }

    func testPRNumberWhenPresent() {
        if let prNumber = BuildMetadata.prNumber {
            XCTAssertGreaterThan(prNumber, 0, "PR number must be positive")
        }
    }
}
