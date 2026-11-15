import XCTest

// MARK: - Quick-select and plan sheets

extension FastedUITests {
    /// The quick-select sheet must start the chosen fast, not the default: the ring's label shows
    /// the stored goal ("24h" rather than "16:8"), and it survives reopening the same store.
    func testStartMenuStartsAnExtendedFast() throws {
        let storeId = UUID().uuidString
        let app = launchIsolatedApp(storeId: storeId)

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "a fresh isolated store must start idle")

        let menuButton = app.buttons["start_fast_menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3), "the quick-select trigger must exist alongside Start")
        menuButton.tap()

        let subtitle = app.staticTexts["quick_select_subtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 3), "the quick-select sheet must explain immediate start")

        let extendedItem = app.buttons["start_menu_24h"]
        XCTAssertTrue(extendedItem.waitForExistence(timeout: 3), "the 24-Hour Fast item must appear in the sheet")
        extendedItem.tap()

        XCTAssertTrue(app.buttons["end_fast_button"].waitForExistence(timeout: 4))
        assertActiveGoalLabel(in: app, is: "24h", message: "the sheet must start a 24-hour fast, not the default")

        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5), "old process must fully exit before reopening its store")
        let relaunched = launchIsolatedApp(storeId: storeId)

        let relaunchedFastTab = relaunched.tabBars.buttons["Fast"]
        XCTAssertTrue(relaunchedFastTab.waitForExistence(timeout: 5))
        relaunchedFastTab.tap()
        XCTAssertTrue(relaunched.buttons["end_fast_button"].waitForExistence(timeout: 5))
        assertActiveGoalLabel(in: relaunched, is: "24h", message: "the 24-hour goal must persist across relaunch")
    }

    /// Verifies there is only a single quick-select entry point while idle (`start_fast_menu`)
    /// rather than competing header/ring pickers, and that GOAL TARGET retargets an active fast.
    func testSingleIdleQuickSelectAndActiveGoalRetargeting() throws {
        let app = launchIsolatedApp()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        XCTAssertTrue(app.staticTexts["fast_status_header"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.buttons["fast_status_header"].exists,
            "idle header must be static so only the split Start Fast button changes the fast"
        )
        XCTAssertFalse(app.staticTexts["Tap to change plan"].exists)

        let menuButton = app.buttons["start_fast_menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3))
        menuButton.tap()

        let extendedItem = app.buttons["start_menu_24h"]
        XCTAssertTrue(extendedItem.waitForExistence(timeout: 3))
        extendedItem.tap()

        XCTAssertTrue(app.buttons["end_fast_button"].waitForExistence(timeout: 4))
        assertActiveGoalLabel(in: app, is: "24h", message: "quick-select should start a 24h fast")

        let goalMenu = app.buttons["goal_target_menu"]
        XCTAssertTrue(goalMenu.waitForExistence(timeout: 3))
        goalMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let changeGoalButton = app.buttons["change_fast_goal_button"]
        XCTAssertTrue(changeGoalButton.waitForExistence(timeout: 3))
        changeGoalButton.tap()

        let retarget16 = app.buttons["retarget_menu_16:8"]
        XCTAssertTrue(retarget16.waitForExistence(timeout: 3))
        retarget16.tap()

        assertActiveGoalLabel(in: app, is: "16:8", message: "retargeting active fast must update the ring goal")
    }

    /// `progress_percentage_text` reads "<n>% · <goal label>" in the default elapsed display mode.
    private func assertActiveGoalLabel(in app: XCUIApplication, is goal: String, message: String) {
        let label = app.staticTexts["progress_percentage_text"]
        XCTAssertTrue(label.waitForExistence(timeout: 3), message)
        XCTAssertTrue(label.label.hasSuffix("· \(goal)"), "\(message) (was \"\(label.label)\")")
    }
}
