import XCTest

/// The AI Lab has no visible entry point, so this is the only thing that fails if the Version-row
/// unlock, the conditional Developer section or its link breaks.
final class DeveloperToolsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTappingVersionSevenTimesRevealsAILabAndHideRemovesIt() throws {
        let app = launchIsolatedApp()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let versionRow = app.descendants(matching: .any)["settings_version_row"].firstMatch
        scrollUntilHittable(versionRow, in: app)
        let aiLabLink = app.buttons["settings_ai_lab_link"]
        XCTAssertFalse(aiLabLink.exists, "developer tools must start hidden")

        for _ in 0..<7 {
            versionRow.tap()
        }

        scrollUntilHittable(aiLabLink, in: app)
        aiLabLink.tap()
        XCTAssertTrue(app.navigationBars["AI Lab"].waitForExistence(timeout: 5))
        app.navigationBars["AI Lab"].buttons["Settings"].tap()

        let hideButton = app.buttons["settings_hide_developer_tools_button"]
        scrollUntilHittable(hideButton, in: app)
        hideButton.tap()
        XCTAssertTrue(aiLabLink.waitForNonExistence(timeout: 5), "Hide must remove the Developer section")
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
    }
}
