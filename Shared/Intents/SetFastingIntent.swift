import AppIntents
import Foundation

public struct SetFastingIntent: AppIntent, SetValueIntent {
    public static var title: LocalizedStringResource = "Toggle Fast"
    public static var description = IntentDescription("Toggles intermittent fasting status.")

    @Parameter(title: "Is Fasting")
    public var value: Bool

    public init() {
        self.value = false
    }

    public init(value: Bool) {
        self.value = value
    }

    public func perform() async throws -> some IntentResult {
        let coordinator = AppGroupCoordinator.shared
        let snapshot = coordinator.readSnapshot()

        if value && !snapshot.isFasting {
            let protoName = snapshot.protocolType ?? FastingProtocol.default.ratioString
            let proto = FastingProtocol.from(protocolType: protoName)
            let now = Date()
            coordinator.enqueueCommand(.startFast(
                startDate: now,
                duration: proto.fastingSeconds,
                protocolType: proto.ratioString
            ))
            let optimistic = snapshot.startingNow(
                startDate: now,
                duration: proto.fastingSeconds,
                protocolType: proto.ratioString
            )
            coordinator.writeSnapshot(optimistic)
        } else if !value && snapshot.isFasting {
            let now = Date()
            coordinator.enqueueCommand(.endFast(endDate: now))
            let optimistic = snapshot.endingNow(at: now)
            coordinator.writeSnapshot(optimistic)
        }

        return .result()
    }
}
