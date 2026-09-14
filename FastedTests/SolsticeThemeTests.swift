import XCTest
import Fasted
import SwiftUI

final class SolsticeThemeTests: XCTestCase {

    func testSolsticeColorsAndGradients() throws {
        XCTAssertNotNil(SolsticeColors.solarGold)
        XCTAssertNotNil(SolsticeColors.solarAmber)
        XCTAssertNotNil(SolsticeColors.solarFlame)
        XCTAssertNotNil(SolsticeColors.emeraldGlow)
        XCTAssertNotNil(SolsticeColors.tealGlow)
        XCTAssertNotNil(SolsticeColors.solarGradient)
        XCTAssertNotNil(SolsticeColors.goalMetGradient)
        XCTAssertNotNil(SolsticeColors.idleGradient)
    }
}
