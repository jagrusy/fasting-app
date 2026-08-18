import XCTest

final class AppStoreScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() throws {
        // Part 1: Fast at 80% progress in Dark Mode
        let app80 = XCUIApplication()
        app80.launchArguments = ["-forceDarkMode", "-seedScreenshots80"]
        app80.launch()

        // 1. Fast Timer Hero (80% Progress with Solar Gold Glow)
        let fastTab = app80.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()
        saveScreenshot(name: "01_FastTimer_80Percent_Hero", in: app80)

        // 2. Metabolic Stages Educational Sheet
        let stageBadge = app80.buttons["metabolic_stage_badge"]
        if stageBadge.waitForExistence(timeout: 3) {
            stageBadge.tap()
            let stagesTitle = app80.navigationBars["Metabolic Fasting Stages"]
            XCTAssertTrue(stagesTitle.waitForExistence(timeout: 3))
            saveScreenshot(name: "03_MetabolicStages_Autophagy", in: app80)

            let doneButton = app80.buttons["stages_done_button"]
            if doneButton.waitForExistence(timeout: 2) {
                doneButton.tap()
            }
        }

        // 3. History Tab Heatmap & Streaks
        let historyTab = app80.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        saveScreenshot(name: "04_History_Calendar_Heatmap", in: app80)

        // 4. Protocol Picker & 24h Dial
        let settingsTab = app80.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let protocolLink = app80.buttons["settings_protocol_navigation_link"]
        if protocolLink.waitForExistence(timeout: 3) {
            protocolLink.tap()
            saveScreenshot(name: "05_ProtocolPicker_CustomDial", in: app80)
            app80.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 5. Settings & Appearance Controls
        saveScreenshot(name: "06_Settings_DarkMode", in: app80)

        // Part 2: Fast at 100%+ Goal Reached in Dark Mode
        let app100 = XCUIApplication()
        app100.launchArguments = ["-forceDarkMode", "-seedScreenshots100"]
        app100.launch()

        let fastTab100 = app100.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab100.waitForExistence(timeout: 5))
        fastTab100.tap()

        saveScreenshot(name: "02_FastTimer_GoalReached_Glow", in: app100)
    }

    private func saveScreenshot(name: String, in app: XCUIApplication) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: "/tmp/SolsticeScreenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)
    }
}
