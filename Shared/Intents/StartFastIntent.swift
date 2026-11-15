import AppIntents
import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

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

        let proto = snapshot.resolvedProtocol
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
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: FastingReminderIDs.allStartReminderIdentifiers)
        #endif
        return .result()
    }
}
