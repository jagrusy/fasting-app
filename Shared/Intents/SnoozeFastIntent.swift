import AppIntents
import Foundation

public struct SnoozeFastIntent: AppIntent {
    public static var title: LocalizedStringResource = "Snooze Fast"
    public static var description = IntentDescription("Extends the active fast goal duration.")

    @Parameter(title: "Extension Minutes", default: 60)
    public var minutes: Int

    public init() {
        self.minutes = 60
    }

    public init(minutes: Int) {
        self.minutes = minutes
    }

    public func perform() async throws -> some IntentResult {
        let coordinator = AppGroupCoordinator.shared
        let snapshot = coordinator.readSnapshot()
        guard snapshot.isFasting else {
            return .result()
        }

        let extensionSeconds = TimeInterval(max(1, minutes) * 60)
        let command = FastingActionCommand.snoozeFast(extensionSeconds: extensionSeconds)
        coordinator.enqueueCommand(command)

        let optimistic = snapshot.snoozed(by: extensionSeconds)
        coordinator.writeSnapshot(optimistic)
        return .result()
    }
}
