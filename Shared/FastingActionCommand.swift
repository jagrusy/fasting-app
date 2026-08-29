import Foundation

public enum FastingActionCommand: Codable, Sendable, Equatable {
    case startFast(startDate: Date, duration: TimeInterval, protocolType: String)
    case endFast(endDate: Date)
    case snoozeFast(extensionSeconds: TimeInterval)
}

public struct PendingCommandEnvelope: Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let command: FastingActionCommand

    public init(id: UUID = UUID(), timestamp: Date = Date(), command: FastingActionCommand) {
        self.id = id
        self.timestamp = timestamp
        self.command = command
    }
}
