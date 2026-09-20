#if os(iOS)
import AppIntents
import Foundation

/// The single action behind the Control Center tile.
///
/// `ControlWidgetTemplateBuilder` has no `buildEither`, so a control cannot branch on state to pick
/// a different intent per case — one intent type has to cover all three and decide at runtime.
///
/// Only the in-progress case opens the app. `openAppWhenRun` is static and would foreground the app
/// on every tap, so that case hands off to `OpenFastTrackerIntent` via `opensIntent` instead, which
/// is what keeps a plain start or a completed end from yanking the user out of whatever they were
/// doing. The non-generic `result(opensIntent:)` is why this target requires iOS 18.2.
public struct FastControlActionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Fast Tracker Control"
    public static var description = IntentDescription(
        "Starts a fast, opens an in-progress one, or ends a fast that has reached its goal."
    )

    public init() {}

    public func perform() async throws -> some IntentResult {
        let snapshot = AppGroupCoordinator.shared.readSnapshot()

        switch FastControlState.from(snapshot: snapshot) {
        case .idle:
            _ = try await StartFastIntent().perform()
            return .result()
        case .complete:
            _ = try await EndFastIntent().perform()
            return .result()
        case .active:
            // Ending early writes a partial fast and breaks the streak, with no undo and no way for
            // a control to confirm. Hand the user to the in-app dialog instead of acting.
            //
            // Nothing is written to the pending deep link on the other two paths: they don't open
            // the app, so a link left behind would hijack the next unrelated foreground.
            return .result(opensIntent: OpenFastTrackerIntent())
        }
    }
}
#endif
