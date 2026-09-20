import AppIntents
import SwiftUI
import WidgetKit

/// A button rather than a toggle, because the action isn't symmetric — see `FastControlState`.
///
/// Starting a fast is one tap to reverse; ending one early writes a partial fast to history and
/// breaks the streak, with no undo and no way for a control to show a confirmation. So the
/// in-progress state opens the app to the in-place confirmation instead of acting, and only the
/// completed state — where `shouldDirectlyEnd` already says an end is safe — ends directly.
struct FastControlWidget: ControlWidget {
    static let kind: String = "com.grusy.SolsticeFast.FastControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: FastControlValueProvider()) { state in
            // No branching here: `ControlWidgetTemplateBuilder` has no `buildEither`, so the state
            // drives the appearance while `FastControlActionIntent` picks the behaviour at runtime.
            ControlWidgetButton(action: FastControlActionIntent()) {
                Label(state.label, systemImage: state.systemImage)
            }
            .tint(state.tintColor)
        }
        .displayName("Fast Tracker")
        .description("Start a fast, check progress, or end it once your goal is met.")
    }
}

/// `SnoozeFastIntent` already existed but was reachable only from a notification action.
struct FastSnoozeControlWidget: ControlWidget {
    static let kind: String = "com.grusy.SolsticeFast.FastSnoozeControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SnoozeFastIntent(minutes: 60)) {
                Label("Extend Fast", systemImage: "plus.circle.fill")
            }
            .tint(SolsticeColors.solarGold)
        }
        .displayName("Extend Fast")
        .description("Add an hour to your active fasting goal.")
    }
}

struct FastControlValueProvider: ControlValueProvider {
    var previewValue: FastControlState {
        .idle
    }

    func currentValue() async throws -> FastControlState {
        FastControlState.from(snapshot: AppGroupCoordinator.shared.readSnapshot())
    }
}
