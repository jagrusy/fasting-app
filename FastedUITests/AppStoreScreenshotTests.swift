import XCTest

final class AppStoreScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Fast Timer Hero
        let fastTab = app.tabBars.buttons["Fast"]
        XCTAssertTrue(fastTab.waitForExistence(timeout: 5))
        fastTab.tap()

        let startButton = app.buttons["start_fast_button"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
        }

        saveScreenshot(name: "01_FastTimer_Hero", in: app)

        // 2. Metabolic Stages Educational Sheet
        let stageBadge = app.buttons["metabolic_stage_badge"]
        if stageBadge.waitForExistence(timeout: 3) {
            stageBadge.tap()
            let stagesTitle = app.navigationBars["Metabolic Fasting Stages"]
            XCTAssertTrue(stagesTitle.waitForExistence(timeout: 3))
            saveScreenshot(name: "02_MetabolicStages_Sheet", in: app)

            let doneButton = app.buttons["stages_done_button"]
            if doneButton.waitForExistence(timeout: 2) {
                doneButton.tap()
            }
        }

        // 3. History Tab Heatmap & Streaks
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        saveScreenshot(name: "03_History_Calendar_Heatmap", in: app)

        // 4. Protocol Picker & 24h Dial
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let protocolLink = app.buttons["settings_protocol_navigation_link"]
        if protocolLink.waitForExistence(timeout: 3) {
            protocolLink.tap()
            saveScreenshot(name: "04_ProtocolPicker_CustomDial", in: app)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 5. Settings & Dark Mode Appearance
        let appearancePicker = app.segmentedControls["appearance_picker"]
        if appearancePicker.waitForExistence(timeout: 3) {
            let darkButton = appearancePicker.buttons["Dark"]
            if darkButton.waitForExistence(timeout: 2) {
                darkButton.tap()
            }
        }
        saveScreenshot(name: "05_Settings_DarkMode", in: app)
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
