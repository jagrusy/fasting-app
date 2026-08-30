import AppIntents
import Foundation

public struct StartFastIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Fast"
    public static var description = IntentDescription("Starts an intermittent fasting timer.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        let coordinator = AppGroupCoordinator.shared
        let snapshot = coordinator.readSnapshot()
        guard !snapshot.isFasting else {
            return .result()
        }

        let protoName = snapshot.protocolType ?? FastingProtocol.default.ratioString
        let proto = FastingProtocol.from(protocolType: protoName)
        let now = Date()
        let command = FastingActionCommand.startFast(
            startDate: now,
            duration: proto.fastingSeconds,
            protocolType: proto.ratioString
        )

        coordinator.enqueueCommand(command)
        let optimistic = snapshot.startingNow(
            startDate: now,
            duration: proto.fastingSeconds,
            protocolType: proto.ratioString
        )
        coordinator.writeSnapshot(optimistic)
        return .result()
    }
}
