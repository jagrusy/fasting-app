import XCTest
import Fasted

@MainActor
final class FeedbackHelperTests: XCTestCase {

    func testFeedbackTypeProperties() throws {
        let feature = FeedbackType.featureRequest
        let bug = FeedbackType.bugReport

        XCTAssertTrue(feature.subject.contains("Feature Request"))
        XCTAssertTrue(bug.subject.contains("Bug Report"))
        XCTAssertFalse(feature.placeholder.isEmpty)
        XCTAssertFalse(bug.placeholder.isEmpty)
    }

    func testSupportEmailIsValidFormat() throws {
        XCTAssertTrue(FeedbackHelper.supportEmail.contains("@"))
        XCTAssertTrue(FeedbackHelper.supportEmail.contains("."))
    }
}
