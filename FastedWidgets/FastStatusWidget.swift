import SwiftUI
import WidgetKit

struct FastStatusWidget: Widget {
    let kind: String = "FastStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastStatusTimelineProvider()) { _ in
            Text("Fast Status")
        }
        .configurationDisplayName("Fast Status")
        .description("Track your fasting progress at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct FastStatusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastStatusEntry {
        FastStatusEntry(date: Date(), snapshot: .idle)
    }

    func getSnapshot(in context: Context, completion: @escaping (FastStatusEntry) -> Void) {
        completion(FastStatusEntry(date: Date(), snapshot: .idle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastStatusEntry>) -> Void) {
        let entry = FastStatusEntry(date: Date(), snapshot: .idle)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct FastStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: FastingStateSnapshot
}
