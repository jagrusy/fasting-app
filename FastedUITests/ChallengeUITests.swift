import XCTest

final class ChallengeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFastingOnlyModeIsDefault() throws {
        let app = launchIsolatedApp()

        let tabBarsQuery = app.tabBars
        XCTAssertTrue(tabBarsQuery.buttons["Fast"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBarsQuery.buttons["History"].exists)
        XCTAssertTrue(tabBarsQuery.buttons["Settings"].exists)

        XCTAssertFalse(tabBarsQuery.buttons["Today"].exists, "Today tab must not appear in fasting-only mode")
        XCTAssertFalse(tabBarsQuery.buttons["Challenge"].exists, "Challenge tab must not appear in fasting-only mode")
    }

    func testEnableChallengesInSettingsRevealsTabs() throws {
        let app = launchIsolatedApp()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let challengesToggle = app.switches["settings_challenges_toggle"]
        XCTAssertTrue(challengesToggle.waitForExistence(timeout: 5))
        challengesToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let tabBarsQuery = app.tabBars
        XCTAssertTrue(tabBarsQuery.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBarsQuery.buttons["Challenge"].exists)
        XCTAssertFalse(tabBarsQuery.buttons["Fast"].exists, "Fast tab is replaced by Today when challenges are enabled")

        let todayTab = tabBarsQuery.buttons["Today"]
        todayTab.tap()
        XCTAssertTrue(app.buttons["today_settings_button"].waitForExistence(timeout: 3))
    }

    func testCreateChallengeAndCheckInFlow() throws {
        let storeId = UUID().uuidString
        let app = launchIsolatedApp(storeId: storeId, enableChallenges: true)

        let challengeTab = app.tabBars.buttons["Challenge"]
        XCTAssertTrue(challengeTab.waitForExistence(timeout: 5))
        challengeTab.tap()

        let createButton = app.buttons["challenge_create_button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let startButton = app.buttons["builder_start_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let challengeCounter = app.staticTexts["challenge_day_counter"]
        XCTAssertTrue(challengeCounter.waitForExistence(timeout: 5))

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let todayCounter = app.staticTexts["today_day_counter"]
        XCTAssertTrue(todayCounter.waitForExistence(timeout: 5))

        let checkButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'today_check_'")
        ).firstMatch
        XCTAssertTrue(checkButton.waitForExistence(timeout: 5))
        checkButton.tap()

        let allDoneBanner = app.staticTexts["today_all_done_banner"]
        XCTAssertTrue(allDoneBanner.waitForExistence(timeout: 5))

        // Verify persistence across app restart
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        let relaunched = launchIsolatedApp(storeId: storeId)

        let relaunchedToday = relaunched.tabBars.buttons["Today"]
        XCTAssertTrue(relaunchedToday.waitForExistence(timeout: 5))
        relaunchedToday.tap()

        XCTAssertTrue(relaunched.staticTexts["today_all_done_banner"].waitForExistence(timeout: 5))
    }

    func testArchiveChallengeReturnsToIdleState() throws {
        let app = launchIsolatedApp(enableChallenges: true)

        let challengeTab = app.tabBars.buttons["Challenge"]
        XCTAssertTrue(challengeTab.waitForExistence(timeout: 5))
        challengeTab.tap()

        let createButton = app.buttons["challenge_create_button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let startButton = app.buttons["builder_start_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let archiveButton = app.buttons["challenge_archive_button"]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 5))
        archiveButton.tap()

        let confirmArchiveButton = app.buttons["Archive Challenge"]
        XCTAssertTrue(confirmArchiveButton.waitForExistence(timeout: 3))
        confirmArchiveButton.tap()

        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Archiving must return to idle create state")

        let pastButton = app.buttons["challenge_view_past_button"]
        XCTAssertTrue(pastButton.waitForExistence(timeout: 3), "Archived challenge must be accessible in history")
    }
}
