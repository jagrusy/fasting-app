import XCTest
@testable import Fasted

/// Drives the Control Center tile. `.active` is the safety-critical case: it must never be treated
/// as an end, because a control can't present the confirmation dialog an early end requires.
final class FastControlStateTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1700000000)

    private func fasting(target: TimeInterval = 16 * 3600) -> FastingStateSnapshot {
        FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: target,
            protocolType: "16:8"
        )
    }

    func testIdleWhenNotFasting() {
        XCTAssertEqual(FastControlState.from(snapshot: .idle, at: start), .idle)
    }

    func testActiveBeforeTheGoalIsMet() {
        XCTAssertEqual(
            FastControlState.from(snapshot: fasting(), at: start.addingTimeInterval(10 * 3600)),
            .active
        )
    }

    func testCompleteAtAndAfterTheGoal() {
        XCTAssertEqual(
            FastControlState.from(snapshot: fasting(), at: start.addingTimeInterval(16 * 3600)),
            .complete
        )
        XCTAssertEqual(
            FastControlState.from(snapshot: fasting(), at: start.addingTimeInterval(30 * 3600)),
            .complete
        )
    }

    /// The tile's behaviour and its appearance are derived from the same value, so a state that
    /// looked complete while behaving as active would be an invisible way to end a fast early.
    func testCompleteIsTheOnlyStateStyledAsAnEnd() {
        XCTAssertEqual(FastControlState.complete.tintColor, SolsticeColors.emeraldGlow)
        XCTAssertEqual(FastControlState.idle.tintColor, SolsticeColors.solarAmber)
        XCTAssertEqual(FastControlState.active.tintColor, SolsticeColors.solarAmber)
        XCTAssertEqual(FastControlState.complete.systemImage, "checkmark.circle.fill")
    }

    func testStateAgreesWithTheDirectEndRule() {
        let midFast = fasting()
        let atTen = start.addingTimeInterval(10 * 3600)
        let atSixteen = start.addingTimeInterval(16 * 3600)

        XCTAssertFalse(FastCommandFactory.shouldDirectlyEnd(snapshot: midFast, at: atTen))
        XCTAssertNotEqual(FastControlState.from(snapshot: midFast, at: atTen), .complete)

        XCTAssertTrue(FastCommandFactory.shouldDirectlyEnd(snapshot: midFast, at: atSixteen))
        XCTAssertEqual(FastControlState.from(snapshot: midFast, at: atSixteen), .complete)
    }
}
