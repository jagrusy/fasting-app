import XCTest
@testable import Fasted

final class FastGaugeMetricsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1700000000)

    private func fasting(target: TimeInterval = 16 * 3600) -> FastingStateSnapshot {
        FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: target,
            protocolType: "16:8"
        )
    }

    func testClampedProgressBoundsAnOverdueFast() {
        let snapshot = fasting()
        XCTAssertEqual(snapshot.clampedProgress(at: start.addingTimeInterval(8 * 3600)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.clampedProgress(at: start.addingTimeInterval(40 * 3600)), 1.0)
        XCTAssertEqual(snapshot.clampedProgress(at: start), 0.0)
    }

    func testClampedProgressIsZeroWhenIdle() {
        XCTAssertEqual(FastingStateSnapshot.idle.clampedProgress(at: start), 0.0)
    }

    func testStageProgressTracksPositionWithinTheCurrentStage() {
        let snapshot = fasting()
        // Glycogen depletion spans 4h...12h, so 8h in sits halfway.
        XCTAssertEqual(snapshot.stageProgress(at: start.addingTimeInterval(8 * 3600)) ?? -1, 0.5, accuracy: 0.0001)
        // Blood sugar reset spans 0h...4h.
        XCTAssertEqual(snapshot.stageProgress(at: start.addingTimeInterval(1 * 3600)) ?? -1, 0.25, accuracy: 0.0001)
    }

    func testStageProgressSaturatesInTheTerminalStage() {
        let snapshot = fasting()
        XCTAssertEqual(snapshot.stageProgress(at: start.addingTimeInterval(40 * 3600)), 1.0)
    }

    func testStageProgressIsNilWhenIdle() {
        XCTAssertNil(FastingStateSnapshot.idle.stageProgress(at: start))
    }

    func testEatingWindowDerivesFromProtocolAndLastCompletedFast() {
        let ended = start.addingTimeInterval(16 * 3600)
        let snapshot = FastingStateSnapshot(
            isFasting: false,
            protocolType: "16:8",
            lastCompletedFastDate: ended
        )

        XCTAssertEqual(snapshot.eatingWindowEnd(), ended.addingTimeInterval(8 * 3600))
        XCTAssertEqual(snapshot.eatingWindowProgress(at: ended.addingTimeInterval(4 * 3600)) ?? -1,
                       0.5,
                       accuracy: 0.0001)
        XCTAssertEqual(snapshot.eatingWindowProgress(at: ended.addingTimeInterval(20 * 3600)), 1.0)
    }

    func testEatingWindowIsUnavailableWhileFasting() {
        XCTAssertNil(fasting().eatingWindowEnd())
        XCTAssertNil(fasting().eatingWindowProgress(at: start))
    }

    func testEatingWindowIsUnavailableBeforeAnyCompletedFast() {
        let snapshot = FastingStateSnapshot(isFasting: false, protocolType: "16:8")
        XCTAssertNil(snapshot.eatingWindowEnd())
        XCTAssertNil(snapshot.eatingWindowProgress(at: start))
    }
}
