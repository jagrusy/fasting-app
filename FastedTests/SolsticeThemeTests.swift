import XCTest
import Fasted
import SwiftUI

final class SolsticeThemeTests: XCTestCase {

    func testAppAppearanceColorSchemes() throws {
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.light.colorScheme, .light)
        XCTAssertEqual(AppAppearance.dark.colorScheme, .dark)
    }

    func testAppAppearanceIcons() throws {
        for mode in AppAppearance.allCases {
            XCTAssertFalse(mode.iconName.isEmpty)
            XCTAssertFalse(mode.rawValue.isEmpty)
        }
    }
}
