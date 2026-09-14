import AppIntents
import SwiftUI
import WidgetKit

struct FastControlWidget: ControlWidget {
    static let kind: String = "com.grusy.SolsticeFast.FastControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: FastControlValueProvider()) { isFasting in
            ControlWidgetToggle(
                isOn: isFasting,
                action: SetFastingIntent(value: !isFasting)
            ) {
                Label(
                    isFasting ? "Fasting" : "Start Fast",
                    systemImage: isFasting ? "flame.fill" : "timer"
                )
            }
            .tint(SolsticeColors.solarAmber)
        }
        .displayName("Fast Tracker")
        .description("Quickly start or end your intermittent fast.")
    }
}

struct FastControlValueProvider: ControlValueProvider {
    var previewValue: Bool {
        false
    }

    func currentValue() async throws -> Bool {
        let snapshot = AppGroupCoordinator.shared.readSnapshot()
        return snapshot.isFasting
    }
}
