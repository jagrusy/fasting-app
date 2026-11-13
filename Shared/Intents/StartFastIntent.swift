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
        #if canImport(UserNotifications)
        let reminderIds = (1...7).flatMap { weekday in
            (0..<4).map { week in
                week == 0 ? "recurring_start_day_\(weekday)" : "recurring_start_day_\(weekday)_\(week)"
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
        #endif
        return .result()
    }
}
