import AppIntents
import SwiftUI
import WidgetKit

struct FastControlWidget: ControlWidget {
    static let kind: String = "FastControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DummyControlIntent()) {
                Label("Fast", systemImage: "timer")
            }
        }
        .displayName("Fast Tracker")
        .description("Start or end your fast.")
    }
}

struct DummyControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Dummy Control Intent"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
