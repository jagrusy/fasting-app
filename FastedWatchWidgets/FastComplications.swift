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
        StaticConfiguration(kind: kind, provider: FastWatchTimelineProvider()) { entry in
            FastComplicationEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Fast Tracker")
        .description("Track your fasting status directly on your Apple Watch face.")
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
        let snapshot = AppGroupCoordinator.shared.readSnapshot()
        completion(FastWatchEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastWatchEntry>) -> Void) {
        let snapshot = AppGroupCoordinator.shared.readSnapshot()
        let now = Date()
        let entries = WidgetTimelineBuilder.entries(for: snapshot, now: now)

        let watchEntries = entries.map { entry in
            FastWatchEntry(date: entry.date, snapshot: entry.snapshot)
        }

        let reloadPolicy: TimelineReloadPolicy
        if let nextDate = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now) {
            reloadPolicy = .after(nextDate)
        } else {
            reloadPolicy = .never
        }

        completion(Timeline(entries: watchEntries, policy: reloadPolicy))
    }
}

struct FastWatchEntry: TimelineEntry {
    let date: Date
    let snapshot: FastingStateSnapshot
}

struct FastComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastWatchEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularFastView(snapshot: entry.snapshot, currentDate: entry.date)
        case .accessoryRectangular:
            AccessoryRectangularFastView(snapshot: entry.snapshot, currentDate: entry.date)
        case .accessoryInline:
            AccessoryInlineFastView(snapshot: entry.snapshot, currentDate: entry.date)
        case .accessoryCorner:
            AccessoryCornerFastView(snapshot: entry.snapshot, currentDate: entry.date)
        default:
            AccessoryCircularFastView(snapshot: entry.snapshot, currentDate: entry.date)
        }
    }
}
