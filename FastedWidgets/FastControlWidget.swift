import AppIntents
import SwiftUI
import WidgetKit

struct FastControlWidget: ControlWidget {
    static let kind: String = "FastControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartFastIntent()) {
                Label("Fast", systemImage: "timer")
            }
        }
        .displayName("Fast Tracker")
        .description("Start or end your fast.")
    }
}
