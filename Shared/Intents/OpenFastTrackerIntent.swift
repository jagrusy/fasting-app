#if os(iOS)
import AppIntents
import Foundation

/// Foregrounds the app on the active fast.
///
/// Exists to be handed to `IntentResult.result(opensIntent:)` so that only some invocations of
/// `FastControlActionIntent` open the app — `openAppWhenRun` is static, so a single intent type
/// can't make that choice at runtime on its own.
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
#endif
