import SwiftUI
import WidgetKit

@main
struct FastWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FastComplications()
    }
}

struct FastComplications: Widget {
    let kind: String = "FastComplications"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastWatchTimelineProvider()) { _ in
            Text("Solstice")
        }
        .configurationDisplayName("Fast Complication")
        .description("Track your fast on Apple Watch.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct FastWatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastWatchEntry {
        FastWatchEntry(date: Date(), snapshot: .idle)
    }

    func getSnapshot(in context: Context, completion: @escaping (FastWatchEntry) -> Void) {
        completion(FastWatchEntry(date: Date(), snapshot: .idle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastWatchEntry>) -> Void) {
        let entry = FastWatchEntry(date: Date(), snapshot: .idle)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct FastWatchEntry: TimelineEntry {
    let date: Date
    let snapshot: FastingStateSnapshot
}
