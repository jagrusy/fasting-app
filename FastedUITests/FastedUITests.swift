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

        if startButton.waitForExistence(timeout: 3) {
            // Start a fast
            startButton.tap()

            // Verify active fasting UI elements
            XCTAssertTrue(endButton.waitForExistence(timeout: 4))
            XCTAssertTrue(app.buttons["progress_ring_button"].exists)

            // Tap End Fast button to bring up confirmation dialog
            endButton.tap()

            // Scope confirmation action to sheets or alert dialogs to avoid query collision
            let sheet = app.sheets["End Fast Early?"]
            if sheet.waitForExistence(timeout: 3) {
                sheet.buttons["End Fast"].tap()
            } else {
                let alert = app.alerts.firstMatch
                if alert.waitForExistence(timeout: 2) {
                    alert.buttons["End Fast"].tap()
                } else if app.buttons["End Fast"].exists {
                    app.buttons["End Fast"].firstMatch.tap()
                }
            }

            // Verify returned to start fast state
            XCTAssertTrue(startButton.waitForExistence(timeout: 4))
        } else if endButton.exists {
            // If already active, end it
            endButton.tap()
            let sheet = app.sheets["End Fast Early?"]
            if sheet.waitForExistence(timeout: 3) {
                sheet.buttons["End Fast"].tap()
            } else {
                let alert = app.alerts.firstMatch
                if alert.waitForExistence(timeout: 2) {
                    alert.buttons["End Fast"].tap()
                } else if app.buttons["End Fast"].exists {
                    app.buttons["End Fast"].firstMatch.tap()
                }
            }
            XCTAssertTrue(startButton.waitForExistence(timeout: 4))
        }
    }

    func testCenterMetricCyclingOnTap() throws {
        let app = XCUIApplication()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        // Ensure active fast
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            XCTAssertTrue(endButton.waitForExistence(timeout: 4))
        }

        let ringButton = app.buttons["progress_ring_button"]
        XCTAssertTrue(ringButton.waitForExistence(timeout: 3))

        // Initial mode: ELAPSED
        XCTAssertTrue(app.staticTexts["ELAPSED"].exists)

        // Tap once -> switches to REMAINING
        ringButton.tap()
        XCTAssertTrue(app.staticTexts["REMAINING"].waitForExistence(timeout: 2))

        // Tap again -> switches to COMPLETED percentage
        ringButton.tap()
        XCTAssertTrue(app.staticTexts["COMPLETED"].waitForExistence(timeout: 2))

        // Tap again -> cycles back to ELAPSED
        ringButton.tap()
        XCTAssertTrue(app.staticTexts["ELAPSED"].waitForExistence(timeout: 2))
    }

    func testHistoryTabDisplaysListOrEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        let navBar = app.navigationBars["History"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        let emptyTitle = app.staticTexts["No Fasts Yet"]
        let fastsCountLabel = app.staticTexts["total_fasts_count_label"]

        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 3) || fastsCountLabel.waitForExistence(timeout: 3))
    }
}
