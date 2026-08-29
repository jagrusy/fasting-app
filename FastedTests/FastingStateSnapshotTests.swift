import XCTest
@testable import Fasted

final class FastingStateSnapshotTests: XCTestCase {
    func testIdleSnapshot() {
        let snapshot = FastingStateSnapshot.idle
        XCTAssertFalse(snapshot.isFasting)
        XCTAssertNil(snapshot.startDate)
        XCTAssertNil(snapshot.targetDuration)
        XCTAssertNil(snapshot.protocolType)
        XCTAssertEqual(snapshot.currentStreak, 0)
        XCTAssertEqual(snapshot.longestStreak, 0)
        XCTAssertNil(snapshot.lastCompletedFastDate)
        XCTAssertEqual(snapshot.elapsedSeconds(), 0)
        XCTAssertNil(snapshot.remainingSeconds())
        XCTAssertEqual(snapshot.progress(), 0.0)
        XCTAssertFalse(snapshot.isGoalMet())
        XCTAssertNil(snapshot.currentStage())
        XCTAssertNil(snapshot.nextStageBoundary())
        XCTAssertNil(snapshot.fastingProtocol)
    }

    func testCodableRoundtrip() throws {
        let start = Date(timeIntervalSince1970: 1700000000)
        let lastCompleted = Date(timeIntervalSince1970: 1699900000)
        let updated = Date(timeIntervalSince1970: 1700010000)

        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 16 * 3600,
            protocolType: "16:8",
            currentStreak: 5,
            longestStreak: 12,
            lastCompletedFastDate: lastCompleted,
            updatedAt: updated
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(FastingStateSnapshot.self, from: data)

        XCTAssertEqual(snapshot, decoded)
        XCTAssertEqual(decoded.isFasting, true)
        XCTAssertEqual(decoded.startDate, start)
        XCTAssertEqual(decoded.targetDuration, 16 * 3600)
        XCTAssertEqual(decoded.protocolType, "16:8")
        XCTAssertEqual(decoded.currentStreak, 5)
        XCTAssertEqual(decoded.longestStreak, 12)
        XCTAssertEqual(decoded.lastCompletedFastDate, lastCompleted)
        XCTAssertEqual(decoded.fastingProtocol?.name, "Popular")
    }

    func testCalculationsBeforeAtAndAfterGoal() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let targetDuration: TimeInterval = 16 * 3600 // 16 hours

        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: targetDuration,
            protocolType: "16:8"
        )

        // 8 hours in (50% progress)
        let eightHoursIn = start.addingTimeInterval(8 * 3600)
        XCTAssertEqual(snapshot.elapsedSeconds(at: eightHoursIn), 8 * 3600)
        XCTAssertEqual(snapshot.remainingSeconds(at: eightHoursIn), 8 * 3600)
        XCTAssertEqual(snapshot.progress(at: eightHoursIn), 0.5, accuracy: 0.001)
        XCTAssertFalse(snapshot.isGoalMet(at: eightHoursIn))

        // Exactly 16 hours in (100% progress, goal met)
        let sixteenHoursIn = start.addingTimeInterval(16 * 3600)
        XCTAssertEqual(snapshot.elapsedSeconds(at: sixteenHoursIn), 16 * 3600)
        XCTAssertEqual(snapshot.remainingSeconds(at: sixteenHoursIn), 0)
        XCTAssertEqual(snapshot.progress(at: sixteenHoursIn), 1.0, accuracy: 0.001)
        XCTAssertTrue(snapshot.isGoalMet(at: sixteenHoursIn))

        // 20 hours in (125% progress, over-goal)
        let twentyHoursIn = start.addingTimeInterval(20 * 3600)
        XCTAssertEqual(snapshot.elapsedSeconds(at: twentyHoursIn), 20 * 3600)
        XCTAssertEqual(snapshot.remainingSeconds(at: twentyHoursIn), 0)
        XCTAssertEqual(snapshot.progress(at: twentyHoursIn), 1.25, accuracy: 0.001)
        XCTAssertTrue(snapshot.isGoalMet(at: twentyHoursIn))
    }

    func testMetabolicStageTransitions() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 24 * 3600,
            protocolType: "Warrior"
        )

        // 2 hours in -> bloodSugarReset
        let twoHours = start.addingTimeInterval(2 * 3600)
        XCTAssertEqual(snapshot.currentStage(at: twoHours), .bloodSugarReset)

        // 6 hours in -> glycogenDepletion
        let sixHours = start.addingTimeInterval(6 * 3600)
        XCTAssertEqual(snapshot.currentStage(at: sixHours), .glycogenDepletion)

        // 14 hours in -> fatBurning
        let fourteenHours = start.addingTimeInterval(14 * 3600)
        XCTAssertEqual(snapshot.currentStage(at: fourteenHours), .fatBurning)

        // 20 hours in -> autophagy
        let twentyHours = start.addingTimeInterval(20 * 3600)
        XCTAssertEqual(snapshot.currentStage(at: twentyHours), .autophagy)

        // 26 hours in -> deepKetosis
        let twentySixHours = start.addingTimeInterval(26 * 3600)
        XCTAssertEqual(snapshot.currentStage(at: twentySixHours), .deepKetosis)
    }

    func testNextStageBoundary() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let snapshot = FastingStateSnapshot(
            isFasting: true,
            startDate: start,
            targetDuration: 24 * 3600,
            protocolType: "16:8"
        )

        // At 2 hours (in bloodSugarReset), next boundary is glycogenDepletion at 4h
        let twoHours = start.addingTimeInterval(2 * 3600)
        let nextAt2h = snapshot.nextStageBoundary(at: twoHours)
        XCTAssertNotNil(nextAt2h)
        XCTAssertEqual(nextAt2h?.stage, .glycogenDepletion)
        XCTAssertEqual(nextAt2h?.date, start.addingTimeInterval(4 * 3600))

        // At 14 hours (in fatBurning), next boundary is autophagy at 18h
        let fourteenHours = start.addingTimeInterval(14 * 3600)
        let nextAt14h = snapshot.nextStageBoundary(at: fourteenHours)
        XCTAssertNotNil(nextAt14h)
        XCTAssertEqual(nextAt14h?.stage, .autophagy)
        XCTAssertEqual(nextAt14h?.date, start.addingTimeInterval(18 * 3600))

        // At 25 hours (in deepKetosis), no next stage exists
        let twentyFiveHours = start.addingTimeInterval(25 * 3600)
        let nextAt25h = snapshot.nextStageBoundary(at: twentyFiveHours)
        XCTAssertNil(nextAt25h)
    }
}
