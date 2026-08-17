import XCTest

final class FastedUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabBarNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // Check tabs exist
        let fastTab = app.tabBars.buttons["Fast"]
        let historyTab = app.tabBars.buttons["History"]
        let settingsTab = app.tabBars.buttons["Settings"]

        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        XCTAssertTrue(historyTab.exists)
        XCTAssertTrue(settingsTab.exists)

        // Switch to history tab
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))

        // Switch to settings tab
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        // Switch back to fast tab
        fastTab.tap()
        XCTAssertTrue(app.navigationBars["Fast"].waitForExistence(timeout: 2))
    }
}
