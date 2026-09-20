import AppIntents
import Foundation

/// Foregrounds the app without changing any state.
///
/// Backs the Control Center tile while a fast is in progress but not yet at goal: ending early has
/// no undo and needs the in-app confirmation dialog, which a control can't present itself, so
/// tapping the tile opens the app instead of running `EndFastIntent` directly.
public struct OpenFastTrackerIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Fast Tracker"
    public static var description = IntentDescription("Opens Solstice to the active fast.")
    public static var openAppWhenRun: Bool { true }

    public init() {}

    public func perform() async throws -> some IntentResult {
        AppGroupCoordinator.shared.writePendingDeepLink(.fastTracker)
        return .result()
    }
}
