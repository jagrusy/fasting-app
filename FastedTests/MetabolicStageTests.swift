import XCTest
import Fasted

final class MetabolicStageTests: XCTestCase {

    func testMetabolicStageProgression() throws {
        XCTAssertEqual(MetabolicStage.stage(for: 0), .bloodSugarReset)
        XCTAssertEqual(MetabolicStage.stage(for: 2 * 3600), .bloodSugarReset)
        XCTAssertEqual(MetabolicStage.stage(for: 4 * 3600), .glycogenDepletion)
        XCTAssertEqual(MetabolicStage.stage(for: 10 * 3600), .glycogenDepletion)
        XCTAssertEqual(MetabolicStage.stage(for: 12 * 3600), .fatBurning)
        XCTAssertEqual(MetabolicStage.stage(for: 16 * 3600), .fatBurning)
        XCTAssertEqual(MetabolicStage.stage(for: 18 * 3600), .autophagy)
        XCTAssertEqual(MetabolicStage.stage(for: 22 * 3600), .autophagy)
        XCTAssertEqual(MetabolicStage.stage(for: 24 * 3600), .deepKetosis)
        XCTAssertEqual(MetabolicStage.stage(for: 48 * 3600), .deepKetosis)
    }

    func testMetabolicStageProperties() throws {
        for stage in MetabolicStage.allCases {
            XCTAssertFalse(stage.title.isEmpty)
            XCTAssertFalse(stage.shortTitle.isEmpty)
            XCTAssertFalse(stage.timeRangeString.isEmpty)
            XCTAssertFalse(stage.systemIcon.isEmpty)
            XCTAssertFalse(stage.summary.isEmpty)
        }
    }
}
