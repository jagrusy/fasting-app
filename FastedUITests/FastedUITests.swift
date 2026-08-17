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
        XCTAssertTrue(app.navigationBars["Fasted"].waitForExistence(timeout: 2))
    }

    func testStartAndEndFastFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Ensure we are on Fast tab
        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        if startButton.exists {
            // Start a fast
            startButton.tap()

            // Verify active fasting UI
            XCTAssertTrue(endButton.waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["elapsed_time_text"].exists)
            XCTAssertTrue(app.staticTexts["progress_percentage_text"].exists)

            // End the fast
            endButton.tap()

            // Confirm in dialog if shown
            let confirmEndButton = app.buttons["End Fast"]
            if confirmEndButton.waitForExistence(timeout: 2) {
                confirmEndButton.tap()
            }

            // Verify returned to start fast state
            XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        } else if endButton.exists {
            // If already active, end it
            endButton.tap()
            let confirmEndButton = app.buttons["End Fast"]
            if confirmEndButton.waitForExistence(timeout: 2) {
                confirmEndButton.tap()
            }
            XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        }
    }
}
