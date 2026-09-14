import AppIntents
import Foundation

public struct EndFastIntent: AppIntent {
    public static var title: LocalizedStringResource = "End Fast"
    public static var description = IntentDescription("Ends the current active fast.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        let coordinator = AppGroupCoordinator.shared
        let snapshot = coordinator.readSnapshot()
        guard snapshot.isFasting else {
            return .result()
        }

        let now = Date()
        let command = FastingActionCommand.endFast(endDate: now)
        coordinator.enqueueCommand(command)

        let optimistic = snapshot.endingNow(at: now)
        coordinator.writeSnapshot(optimistic)
        return .result()
    }
}
