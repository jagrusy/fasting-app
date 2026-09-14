import Foundation

public struct WatchPayload {
    public static let snapshotKey = "snapshot_payload"
    public static let commandKey = "command_payload"

    public static func encodeSnapshot(_ snapshot: FastingStateSnapshot) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snapshot) else { return nil }
        return [snapshotKey: data]
    }

    public static func decodeSnapshot(from dictionary: [String: Any]) -> FastingStateSnapshot? {
        guard let data = dictionary[snapshotKey] as? Data else { return nil }
        return try? JSONDecoder().decode(FastingStateSnapshot.self, from: data)
    }

    public static func encodeCommand(_ envelope: PendingCommandEnvelope) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(envelope) else { return nil }
        return [commandKey: data]
    }

    public static func decodeCommand(from dictionary: [String: Any]) -> PendingCommandEnvelope? {
        guard let data = dictionary[commandKey] as? Data else { return nil }
        return try? JSONDecoder().decode(PendingCommandEnvelope.self, from: data)
    }
}
