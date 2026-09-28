import XCTest

final class JournalUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFoodJournalIsDefaultDisabled() throws {
        let app = launchIsolatedApp()

        let tabBarsQuery = app.tabBars
        XCTAssertTrue(tabBarsQuery.buttons["Fast"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBarsQuery.buttons["History"].exists)
        XCTAssertTrue(tabBarsQuery.buttons["Settings"].exists)

        XCTAssertFalse(tabBarsQuery.buttons["Journal"].exists, "Journal tab must not appear when disabled")
    }

    func testEnableFoodJournalInSettingsRevealsJournalTab() throws {
        let app = launchIsolatedApp()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let journalToggle = app.switches["settings_journal_toggle"]
        XCTAssertTrue(journalToggle.waitForExistence(timeout: 5))
        journalToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let tabBarsQuery = app.tabBars
        XCTAssertTrue(tabBarsQuery.buttons["Journal"].waitForExistence(timeout: 5))
        XCTAssertFalse(tabBarsQuery.buttons["History"].exists, "History tab is replaced by Journal")

        let journalTab = tabBarsQuery.buttons["Journal"]
        journalTab.tap()
        XCTAssertTrue(app.buttons["journal_log_meal_button"].waitForExistence(timeout: 3))
    }

    func testLogMealAndVerifyPersistenceAcrossRelaunch() throws {
        let storeId = UUID().uuidString
        let app = launchIsolatedApp(storeId: storeId, enableJournal: true)

        let journalTab = app.tabBars.buttons["Journal"]
        XCTAssertTrue(journalTab.waitForExistence(timeout: 5))
        journalTab.tap()

        let logMealButton = app.buttons["journal_log_meal_button"]
        XCTAssertTrue(logMealButton.waitForExistence(timeout: 5))
        logMealButton.tap()

        let notesField = app.textFields["meal_composer_notes_input"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        notesField.tap()
        notesField.typeText("Avocado and scrambled eggs")

        let saveButton = app.buttons["meal_composer_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let mealRow = app.staticTexts["Avocado and scrambled eggs"]
        XCTAssertTrue(mealRow.waitForExistence(timeout: 5))

        // Verify persistence across app restart
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        let relaunched = launchIsolatedApp(storeId: storeId, enableJournal: true)

        let relaunchedJournal = relaunched.tabBars.buttons["Journal"]
        XCTAssertTrue(relaunchedJournal.waitForExistence(timeout: 5))
        relaunchedJournal.tap()

        XCTAssertTrue(relaunched.staticTexts["Avocado and scrambled eggs"].waitForExistence(timeout: 5))
    }

    func testPostFastMealPromptAndDontAskAgain() throws {
        let app = launchIsolatedApp(enableJournal: true, enablePostFastPrompt: true)

        let startButton = app.buttons["start_fast_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let endButton = app.buttons["end_fast_button"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        let confirmEndButton = app.buttons["Save Fast"]
        XCTAssertTrue(confirmEndButton.waitForExistence(timeout: 5))
        confirmEndButton.tap()

        // Post-fast invitation sheet should appear
        let dontAskButton = app.buttons["meal_composer_dont_ask_button"]
        XCTAssertTrue(dontAskButton.waitForExistence(timeout: 5))
        dontAskButton.tap()

        // Wait for dismissal
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        // Start and end a second fast: prompt should NOT appear
        startButton.tap()
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()
        XCTAssertTrue(confirmEndButton.waitForExistence(timeout: 5))
        confirmEndButton.tap()

        XCTAssertFalse(
            app.buttons["meal_composer_dont_ask_button"].waitForExistence(timeout: 3),
            "Prompt must not appear after permanent opt-out"
        )
    }
}
