import XCTest
import CoreGraphics

final class FastedUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System Dialogs") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            return false
        }
    }

    private func makeApp(
        storeName: String = "uitest_\(UUID().uuidString)",
        arguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-testStoreName", storeName] + arguments
        return app
    }

    func testAppLaunchesWithThreeTabs() throws {
        let app = makeApp()
        app.launch()
        let tabBarsQuery = app.tabBars
        XCTAssertTrue(tabBarsQuery.buttons["Fast"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBarsQuery.buttons["History"].exists)
        XCTAssertTrue(tabBarsQuery.buttons["Settings"].exists)
    }

    func testFastTabBasicUIElements() throws {
        let app = makeApp()
        app.launch()
        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let navBar = app.navigationBars["Solstice"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))
        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start fast button must exist on fresh launch")
        XCTAssertFalse(endButton.exists, "End fast button must not exist before starting a fast")
    }

    func testStartAndEndFastFlow() throws {
        let store = "startEnd_\(UUID().uuidString)"
        let app = makeApp(storeName: store)
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start fast button must exist on clean launch")
        XCTAssertFalse(endButton.exists, "End fast button must not exist before starting")

        startButton.tap()
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End fast button must appear after starting fast")

        let statusHeader = app.staticTexts["fast_status_header"]
        XCTAssertTrue(statusHeader.waitForExistence(timeout: 3), "Status header must appear when fasting")
        XCTAssertEqual(statusHeader.label, "Fasting in Progress")

        endButton.tap()
        let saveButton = app.buttons["Save Fast"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save Fast button must appear in confirmation")
        saveButton.tap()

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start fast button must return after saving fast")
        XCTAssertFalse(endButton.exists, "End fast button must disappear after saving fast")

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No Completed Fasts Yet"].exists, "History must display saved fast")

        app.terminate()
        let relaunchedApp = makeApp(storeName: store)
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.buttons["start_fast_button"].waitForExistence(timeout: 5))
        XCTAssertFalse(relaunchedApp.buttons["end_fast_button"].exists)

        let relaunchedHistoryTab = relaunchedApp.tabBars.buttons["History"]
        XCTAssertTrue(relaunchedHistoryTab.waitForExistence(timeout: 5))
        relaunchedHistoryTab.tap()
        XCTAssertTrue(relaunchedApp.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertFalse(relaunchedApp.staticTexts["No Completed Fasts Yet"].exists)
    }

    func testDiscardFastFlow() throws {
        let store = "discard_\(UUID().uuidString)"
        let app = makeApp(storeName: store)
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start button must exist initially")
        startButton.tap()

        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End button must exist after starting")
        endButton.tap()

        let discardButton = app.buttons["Discard Fast"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5), "Discard Fast button must appear in confirmation")
        discardButton.tap()

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start button must return after discarding fast")
        XCTAssertFalse(endButton.exists, "End button must not exist after discarding")

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.staticTexts["No Completed Fasts Yet"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunchedApp = makeApp(storeName: store)
        relaunchedApp.launch()

        let relaunchedHistoryTab = relaunchedApp.tabBars.buttons["History"]
        XCTAssertTrue(relaunchedHistoryTab.waitForExistence(timeout: 5))
        relaunchedHistoryTab.tap()
        XCTAssertTrue(relaunchedApp.staticTexts["No Completed Fasts Yet"].waitForExistence(timeout: 5))
    }

    func testStartFastWithDeniedNotificationsContinuesTimer() throws {
        let store = "deniedNotifs_\(UUID().uuidString)"
        let app = makeApp(storeName: store)
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start fast button must exist initially")
        startButton.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let dontAllowButton = springboard.alerts.buttons["Don’t Allow"]
        if dontAllowButton.waitForExistence(timeout: 2) {
            dontAllowButton.tap()
        }

        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End fast button must appear with denied notifications")
        let statusHeader = app.staticTexts["fast_status_header"]
        XCTAssertTrue(statusHeader.waitForExistence(timeout: 3))
        XCTAssertEqual(statusHeader.label, "Fasting in Progress")

        endButton.tap()
        let saveButton = app.buttons["Save Fast"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
    }

    func testCenterMetricCyclingOnTap() throws {
        let app = makeApp()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))

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
        let app = makeApp()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))

        let knob = app.otherElements["progress_knob"]
        XCTAssertTrue(knob.waitForExistence(timeout: 3), "Progress knob must exist and be accessible")

        let elapsedLabel = app.staticTexts["elapsed_time_text"]
        XCTAssertTrue(elapsedLabel.waitForExistence(timeout: 2))
        let initialElapsed = elapsedLabel.label

        let startCoord = knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let targetCoord = startCoord.withOffset(CGVector(dx: 90, dy: 90))
        startCoord.press(forDuration: 0.1, thenDragTo: targetCoord)

        let updatedElapsed = elapsedLabel.label
        XCTAssertNotEqual(initialElapsed, updatedElapsed, "Dragging progress knob must update elapsed time!")
    }

    func testHistoryTabDisplaysListOrEmptyState() throws {
        let app = makeApp()
        app.launch()
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        let navBar = app.navigationBars["History"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 8))
        let emptyTitle = app.staticTexts["No Completed Fasts Yet"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 5), "Empty state must appear on clean launch")
    }

    func testHistoryTabMonthNavigation() throws {
        let app = makeApp()
        app.launch()
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        let prevButton = app.buttons["calendar_prev_month_button"]
        XCTAssertTrue(prevButton.waitForExistence(timeout: 4))
        prevButton.tap()
        let nextButton = app.buttons["calendar_next_month_button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 4))
        nextButton.tap()
    }

    func testMetabolicStagesSheetOpensAndDismisses() throws {
        let app = makeApp()
        app.launch()

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

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
}

// MARK: - Settings and Deep Links
extension FastedUITests {

    func testSettingsTabProtocolSelection() throws {
        let app = makeApp()
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

        let protocolNavBar = app.navigationBars["Fasting Protocol"]
        XCTAssertTrue(protocolNavBar.waitForExistence(timeout: 3))
        let backButton = protocolNavBar.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        // Tap button coordinate directly to avoid CI headless scroll-into-view failure
        backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.staticTexts["Warrior"].waitForExistence(timeout: 3))
    }

    func testSettingsTabMedicalDisclaimerModal() throws {
        let app = makeApp()
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

    func testSettingsTabFeedbackButtonsExist() throws {
        let app = makeApp()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let featureButton = app.buttons["settings_suggest_feature_button"]
        let reportButton = app.buttons["settings_report_issue_button"]
        let rateButton = app.buttons["settings_rate_app_button"]

        if !featureButton.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(featureButton.waitForExistence(timeout: 3))
        XCTAssertTrue(reportButton.waitForExistence(timeout: 3))
        XCTAssertTrue(rateButton.waitForExistence(timeout: 3))
    }

    func testDeepLinkOpensHistoryTab() throws {
        let app = makeApp()
        app.launch()

        // The app opens on Fast, so landing on History proves the link moved it.
        XCTAssertTrue(app.navigationBars["Solstice"].waitForExistence(timeout: 5))
        XCUIDevice.shared.system.open(URL(string: "solstice://history")!)
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10))
    }

    func testDeepLinkOpensFastTrackerFromAnotherTab() throws {
        let app = makeApp()
        app.launch()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 8))

        XCUIDevice.shared.system.open(URL(string: "solstice://fastTracker")!)
        XCTAssertTrue(app.navigationBars["Solstice"].waitForExistence(timeout: 10))
    }

    func testUnknownDeepLinkLeavesTheCurrentTabAlone() throws {
        let app = makeApp()
        app.launch()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 8))

        XCUIDevice.shared.system.open(URL(string: "solstice://nonsense")!)
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["Solstice"].exists)
    }
}
