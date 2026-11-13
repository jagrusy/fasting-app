import XCTest
@testable import Fasted

// MARK: - Fixed-length and custom fasts

extension FastedTests {
    func testExtendedPresetsAreFixedLengthWithNoEatingWindow() {
        XCTAssertEqual(FastingProtocol.extendedPresets.map(\.id), ["24h", "36h", "48h", "72h"])
        XCTAssertEqual(FastingProtocol.allPresets.count, FastingProtocol.presets.count + 4)

        let thirtySix = FastingProtocol.from(protocolType: "36h")
        XCTAssertEqual(thirtySix.name, "36-Hour Fast")
        XCTAssertEqual(thirtySix.ratioString, "36h")
        XCTAssertEqual(thirtySix.fastingSeconds, 36 * 3600)
        XCTAssertFalse(thirtySix.hasEatingWindow)
    }

    /// Regression: any identifier that wasn't a daily ratio used to read back as 16:8, so a stored
    /// long or custom fast would have shown, and restarted, as a 16-hour one.
    func testCustomFixedLengthRoundTripsThroughItsIdentifier() {
        let custom = FastingProtocol.fixedLength(hours: 30)
        XCTAssertEqual(custom.id, "30h")
        XCTAssertEqual(custom.name, "Custom")

        let parsed = FastingProtocol.from(protocolType: custom.ratioString)
        XCTAssertEqual(parsed, custom)
        XCTAssertEqual(parsed.fastingSeconds, 30 * 3600)

        // Shorter than a day: the rest of the day is still an eating window.
        let eighteen = FastingProtocol.from(protocolType: "18h")
        XCTAssertEqual(eighteen.eatingHours, 6)
        XCTAssertTrue(eighteen.hasEatingWindow)

        XCTAssertEqual(FastingProtocol.customHoursRange, 12...72)
    }

    func testMalformedIdentifiersStillFallBackToDefault() {
        for bad in ["h", "0h", "-5h", "abch", "36", "169h", "16:9"] {
            XCTAssertNil(FastingProtocol.known(protocolType: bad), bad)
            XCTAssertEqual(FastingProtocol.from(protocolType: bad).ratioString, "16:8", bad)
        }
        XCTAssertEqual(FastingProtocol.from(protocolType: "16:8").ratioString, "16:8")
    }

    func testFastingProtocolLabelForFixedLengthFasts() {
        XCTAssertEqual(FastingProtocol.label(forTargetDuration: 72 * 3600, protocolType: "72h"), "72h")
        XCTAssertEqual(FastingProtocol.label(forTargetDuration: 30 * 3600, protocolType: "30h"), "30h")
        XCTAssertEqual(FastingProtocol.label(forTargetDuration: 31 * 3600, protocolType: "30h"), "Custom")
    }
}

// MARK: - Custom fast start-menu additions

extension FastedTests {
    func testLastCustomFastHoursRoundTripsThroughIsolatedDefaults() throws {
        let manager = try XCTUnwrap(fastManager)
        XCTAssertNil(manager.lastCustomFastHours)

        manager.rememberCustomFastHours(30)
        XCTAssertEqual(manager.lastCustomFastHours, 30)

        manager.rememberCustomFastHours(48)
        XCTAssertEqual(manager.lastCustomFastHours, 48)
    }

    func testLastCustomFastHoursRejectsOutOfRangeValues() throws {
        let manager = try XCTUnwrap(fastManager)

        manager.rememberCustomFastHours(30)
        XCTAssertEqual(manager.lastCustomFastHours, 30)

        manager.rememberCustomFastHours(11) // below FastingProtocol.customHoursRange
        XCTAssertEqual(manager.lastCustomFastHours, 30, "an out-of-range value must not overwrite the last valid one")

        manager.rememberCustomFastHours(73) // above FastingProtocol.customHoursRange
        XCTAssertEqual(manager.lastCustomFastHours, 30)
    }

    func testStartingFixedLengthCustomFastLeavesCurrentProtocolUnchanged() throws {
        let manager = try XCTUnwrap(fastManager)
        XCTAssertEqual(manager.currentProtocol.ratioString, "16:8")

        let custom = FastingProtocol.fixedLength(hours: 30)
        let fast = try XCTUnwrap(manager.startFast(
            startDate: Date(),
            targetDuration: custom.fastingSeconds,
            protocolType: custom.ratioString
        ))

        XCTAssertEqual(fast.protocolType, "30h")
        XCTAssertEqual(fast.targetDuration, 30 * 3600)
        XCTAssertEqual(manager.currentProtocol.ratioString, "16:8")
    }
}
