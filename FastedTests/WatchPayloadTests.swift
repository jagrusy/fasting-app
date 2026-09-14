import XCTest
@testable import Fasted

final class WatchPayloadTests: XCTestCase {
    func testSnapshotRoundTrip() {
        let original = FastingStateSnapshot(
            isFasting: true,
            startDate: Date(timeIntervalSince1970: 1700000000),
            targetDuration: 16 * 3600,
            protocolType: "16:8",
            currentStreak: 4,
            longestStreak: 10,
            lastCompletedFastDate: Date(timeIntervalSince1970: 1699900000),
            updatedAt: Date(timeIntervalSince1970: 1700001000)
        )

        let dict = WatchPayload.encodeSnapshot(original)
        XCTAssertNotNil(dict)
        guard let unwrappedDict = dict else { return }

        let decoded = WatchPayload.decodeSnapshot(from: unwrappedDict)
        XCTAssertEqual(decoded, original)
    }

    func testCommandRoundTrip() {
        let envelope = PendingCommandEnvelope(
            timestamp: Date(timeIntervalSince1970: 1700000010),
            command: .startFast(
                startDate: Date(timeIntervalSince1970: 1700000000),
                duration: 18 * 3600,
                protocolType: "18:6"
            )
        )

        let dict = WatchPayload.encodeCommand(envelope)
        XCTAssertNotNil(dict)

        guard let unwrappedDict = dict else { return }

        let decoded = WatchPayload.decodeCommand(from: unwrappedDict)
        XCTAssertEqual(decoded, envelope)
    }

    func testInvalidDictionaryDecoding() {
        XCTAssertNil(WatchPayload.decodeSnapshot(from: [:]))
        XCTAssertNil(WatchPayload.decodeCommand(from: [:]))
    }
}
