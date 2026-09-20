import XCTest
@testable import Fasted

final class DeepLinkTests: XCTestCase {
    func testRoundTripsThroughItsURL() {
        for link in [DeepLink.fastTracker, .history] {
            XCTAssertEqual(DeepLink(url: link.url), link)
        }
    }

    func testURLUsesTheRegisteredScheme() {
        XCTAssertEqual(DeepLink.fastTracker.url.absoluteString, "solstice://fastTracker")
        XCTAssertEqual(DeepLink.history.url.absoluteString, "solstice://history")
    }

    /// The scheme string is duplicated in `Fasted/Info.plist` under `CFBundleURLTypes`; nothing
    /// routes without that registration, and nothing else would catch a rename.
    func testSchemeMatchesTheBundleRegistration() throws {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let schemes = (types ?? []).compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 }
        XCTAssertTrue(
            schemes.contains(DeepLink.scheme),
            "Info.plist registers \(schemes), which does not include \(DeepLink.scheme)"
        )
    }

    func testRejectsForeignSchemesAndUnknownHosts() {
        XCTAssertNil(DeepLink(url: URL(string: "https://fastTracker")!))
        XCTAssertNil(DeepLink(url: URL(string: "solstice://settings")!))
        XCTAssertNil(DeepLink(url: URL(string: "solstice://")!))
    }

    /// A tap outside any button goes to the active fast while one is running, and to history
    /// otherwise — an idle widget has nothing live to show.
    func testWidgetTapTargetFollowsFastingState() {
        XCTAssertEqual(DeepLink.forWidgetTap(isFasting: true), .fastTracker)
        XCTAssertEqual(DeepLink.forWidgetTap(isFasting: false), .history)
    }
}
