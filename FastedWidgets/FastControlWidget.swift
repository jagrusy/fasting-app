import AppIntents
import SwiftUI
import WidgetKit

/// A control that toggles fasting status, with its label, icon, and tint adapting dynamically
/// to the current fasting state (idle, active, complete).
struct FastControlWidget: ControlWidget {
    static let kind: String = "com.grusy.SolsticeFast.FastControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: FastControlValueProvider()) { state in
            ControlWidgetToggle(
                isOn: state != .idle,
                action: SetFastingIntent(value: state == .idle)
            ) {
                Label(
                    state.label,
                    systemImage: state.systemImage
                )
            }
            .tint(state.tintColor)
        }
        .displayName("Fast Tracker")
        .description("Quickly start or end your intermittent fast.")
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
