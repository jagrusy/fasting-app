import XCTest

final class FastedUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesWithThreeTabs() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBarsQuery = app.tabBars
        XCTAssertTrue(tabBarsQuery.buttons["Fast"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBarsQuery.buttons["History"].exists)
        XCTAssertTrue(tabBarsQuery.buttons["Settings"].exists)
    }

    func testFastTabBasicUIElements() throws {
        let app = XCUIApplication()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let navBar = app.navigationBars["Solstice"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3) || endButton.waitForExistence(timeout: 3))
    }

    func testStartAndEndFastFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        if startButton.waitForExistence(timeout: 3) {
            startButton.tap()
            XCTAssertTrue(endButton.waitForExistence(timeout: 4))

            let statusHeader = app.staticTexts["fast_status_header"]
            XCTAssertTrue(statusHeader.waitForExistence(timeout: 2))

            endButton.tap()
            let alert = app.alerts.firstMatch
            if alert.waitForExistence(timeout: 2) {
                alert.buttons["End Fast"].tap()
            } else if app.buttons["End Fast"].exists {
                app.buttons["End Fast"].firstMatch.tap()
            }
            XCTAssertTrue(startButton.waitForExistence(timeout: 4))
        } else if endButton.waitForExistence(timeout: 3) {
            endButton.tap()
            let alert = app.alerts.firstMatch
            if alert.waitForExistence(timeout: 2) {
                alert.buttons["End Fast"].tap()
            } else if app.buttons["End Fast"].exists {
                app.buttons["End Fast"].firstMatch.tap()
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

        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            XCTAssertTrue(endButton.waitForExistence(timeout: 4))
        }

        let ringButton = app.buttons["progress_ring_button"]
        XCTAssertTrue(ringButton.waitForExistence(timeout: 3))

        XCTAssertTrue(app.staticTexts["ELAPSED"].exists)

        ringButton.tap()
        XCTAssertTrue(app.staticTexts["REMAINING"].waitForExistence(timeout: 2))

        ringButton.tap()
        XCTAssertTrue(app.staticTexts["COMPLETED"].waitForExistence(timeout: 2))

        ringButton.tap()
        XCTAssertTrue(app.staticTexts["ELAPSED"].waitForExistence(timeout: 2))
    }

    func testProgressRingKnobDraggingUpdatesProgressAndElapsedTime() throws {
        let app = XCUIApplication()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            XCTAssertTrue(endButton.waitForExistence(timeout: 4))
        }

        let knob = app.otherElements["progress_knob"]
        XCTAssertTrue(knob.waitForExistence(timeout: 3), "Progress knob must exist and be accessible")

        let elapsedLabel = app.staticTexts["elapsed_time_text"]
        XCTAssertTrue(elapsedLabel.waitForExistence(timeout: 2))
        let initialElapsed = elapsedLabel.label

        let startCoord = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let targetCoord = startCoord.withOffset(CGVector(dx: 90, dy: 90))
        startCoord.press(forDuration: 0.1, thenDragTo: targetCoord)

        let updatedElapsed = elapsedLabel.label
        XCTAssertNotEqual(initialElapsed, updatedElapsed, "Dragging the progress knob must update elapsed time!")
    }

    func testHistoryTabDisplaysListOrEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        let navBar = app.navigationBars["History"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        let emptyTitle = app.staticTexts["No Completed Fasts Yet"]
        let currentStreakLabel = app.staticTexts["current_streak_label"]

        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 3) || currentStreakLabel.waitForExistence(timeout: 3))
    }

    func testSettingsTabProtocolSelection() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let navBar = app.navigationBars["Settings"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        let protocolLink = app.buttons["settings_protocol_navigation_link"]
        XCTAssertTrue(protocolLink.waitForExistence(timeout: 3))
        protocolLink.tap()

        let warriorCard = app.buttons["protocol_card_20:4"]
        XCTAssertTrue(warriorCard.waitForExistence(timeout: 3))
        warriorCard.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["Warrior"].waitForExistence(timeout: 3))
    }

    func testSettingsTabMedicalDisclaimerModal() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let disclaimerButton = app.buttons["settings_medical_disclaimer_button"]
        if !disclaimerButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(disclaimerButton.waitForExistence(timeout: 3))
        disclaimerButton.tap()

        let disclaimerTitle = app.navigationBars["Medical Disclaimer"]
        XCTAssertTrue(disclaimerTitle.waitForExistence(timeout: 3))

        let doneButton = app.buttons["disclaimer_done_button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2))
        doneButton.tap()

        XCTAssertFalse(disclaimerTitle.exists)
    }

    func testMetabolicStagesSheetOpensAndDismisses() throws {
        let app = XCUIApplication()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
        }

        let stageBadge = app.buttons["metabolic_stage_badge"]
        XCTAssertTrue(stageBadge.waitForExistence(timeout: 3))
        stageBadge.tap()

        let stagesTitle = app.navigationBars["Metabolic Fasting Stages"]
        XCTAssertTrue(stagesTitle.waitForExistence(timeout: 3))

        let doneButton = app.buttons["stages_done_button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2))
        doneButton.tap()

        XCTAssertFalse(stagesTitle.exists)
    }

    func testSettingsTabAppearanceSelection() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let appearancePicker = app.segmentedControls["appearance_picker"]
        XCTAssertTrue(appearancePicker.waitForExistence(timeout: 3))

        let darkButton = appearancePicker.buttons["Dark"]
        if darkButton.waitForExistence(timeout: 2) {
            darkButton.tap()
        }

        let systemButton = appearancePicker.buttons["System"]
        if systemButton.waitForExistence(timeout: 2) {
            systemButton.tap()
        }
    }
}
