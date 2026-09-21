import XCTest
import CoreGraphics

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

    /// Regression: the previous `if` / `else if` had no `else`, so a launch where neither button
    /// existed — a crash, the wrong tab, a broken build — ran zero assertions and reported a pass.
    /// The branch existed because the test had no way to know whether a fast was already active on
    /// the shared store; an isolated, guaranteed-empty store removes that ambiguity; a fresh store
    /// can only ever start idle.
    func testStartAndEndFastFlow() throws {
        let storeId = UUID().uuidString
        let app = launchIsolatedApp(storeId: storeId)

        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        let endButton = app.buttons["end_fast_button"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "A fresh, isolated store must start idle")
        startButton.tap()

        XCTAssertTrue(endButton.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["fast_status_header"].waitForExistence(timeout: 2))

        endButton.tap()
        dismissEndFastConfirmationIfNeeded(in: app)
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        assertExactlyOneHistoryEntry(in: app, message: "saving the ended fast must record exactly one history entry")

        // A fresh process reopening the same store: proves the save actually persisted to disk
        // rather than only updating in-memory UI state. `terminate()` requests termination but
        // doesn't wait for the OS to finish tearing the process down; relaunching immediately can
        // race the new process's `NSPersistentContainer.loadPersistentStores` against the old
        // process's SQLite file locks (confirmed live: an immediate relaunch crashed on reopening
        // the same store). `wait(for: .notRunning)` is XCTest's own API for this exact race.
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5), "old process must fully exit before reopening its store")
        let relaunched = launchIsolatedApp(storeId: storeId)

        let relaunchedHistoryTab = relaunched.tabBars.buttons["History"]
        XCTAssertTrue(relaunchedHistoryTab.waitForExistence(timeout: 5))
        relaunchedHistoryTab.tap()
        assertExactlyOneHistoryEntry(in: relaunched, message: "the saved fast must still be present after relaunch")
    }

    private func dismissEndFastConfirmationIfNeeded(in app: XCUIApplication) {
        let saveButton = app.buttons["Save Fast"]
        let discardButton = app.buttons["Discard Fast"]
        let alert = app.alerts.firstMatch

        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
        } else if discardButton.waitForExistence(timeout: 2) {
            discardButton.tap()
        } else if alert.waitForExistence(timeout: 2) {
            if alert.buttons["End Fast"].exists {
                alert.buttons["End Fast"].tap()
            } else if alert.buttons.element(boundBy: 0).exists {
                alert.buttons.element(boundBy: 0).tap()
            }
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
        XCTAssertTrue(navBar.waitForExistence(timeout: 8))

        let emptyTitle = app.staticTexts["No Completed Fasts Yet"]
        let currentStreakLabel = app.staticTexts["current_streak_label"]

        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 8) || currentStreakLabel.waitForExistence(timeout: 8))
    }

    func testHistoryTabMonthNavigation() throws {
        let app = XCUIApplication()
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

        let protocolNavBar = app.navigationBars["Fasting Protocol"]
        XCTAssertTrue(protocolNavBar.waitForExistence(timeout: 3))
        let backButton = protocolNavBar.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        // A plain `.tap()` here reliably fails on GitHub's macOS runners with "Failed to scroll
        // to visible (by AX action)" even though the button is already fully on-screen and not
        // inside any scroll view — `.tap()` still routes through an AX-driven
        // is-this-hittable/scroll-into-view check before synthesizing the touch, and that check
        // itself is what's failing in CI's headless accessibility server. Tapping a raw
        // coordinate on the button skips that check and goes straight to a synthetic touch.
        backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

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

    func testSettingsTabFeedbackButtonsExist() throws {
        let app = XCUIApplication()
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

    // MARK: - Deep links

    /// Exercises the real scheme registration end to end: the system resolves `solstice://` from
    /// `CFBundleURLTypes`, launches the app, and `onOpenURL` picks the tab. A unit test can only
    /// check the URL parsing, not that any of that plumbing is actually connected.
    func testDeepLinkOpensHistoryTab() throws {
        let app = XCUIApplication()
        app.launch()

        // The app opens on Fast, so landing on History proves the link moved it.
        XCTAssertTrue(app.navigationBars["Solstice"].waitForExistence(timeout: 5))

        XCUIDevice.shared.system.open(URL(string: "solstice://history")!)

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10))
    }

    func testDeepLinkOpensFastTrackerFromAnotherTab() throws {
        let app = XCUIApplication()
        app.launch()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 8))

        XCUIDevice.shared.system.open(URL(string: "solstice://fastTracker")!)

        XCTAssertTrue(app.navigationBars["Solstice"].waitForExistence(timeout: 10))
    }

    /// An unrecognised host must be ignored rather than moving the user somewhere arbitrary.
    func testUnknownDeepLinkLeavesTheCurrentTabAlone() throws {
        let app = XCUIApplication()
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
