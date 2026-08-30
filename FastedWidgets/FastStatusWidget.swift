import AppIntents
import SwiftUI
import WidgetKit

struct FastStatusWidget: Widget {
    let kind: String = "FastStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastStatusTimelineProvider()) { entry in
            FastStatusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Fast Tracker")
        .description("Track your fasting progress and metabolic stages.")
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
    func placeholder(in context: Context) -> FastStatusWidgetEntry {
        FastStatusWidgetEntry(date: Date(), snapshot: .idle)
    }

    func getSnapshot(in context: Context, completion: @escaping (FastStatusWidgetEntry) -> Void) {
        let snapshot = AppGroupCoordinator.shared.readSnapshot()
        completion(FastStatusWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastStatusWidgetEntry>) -> Void) {
        let snapshot = AppGroupCoordinator.shared.readSnapshot()
        let now = Date()
        let entries = WidgetTimelineBuilder.entries(for: snapshot, now: now)

        let widgetEntries = entries.map { entry in
            FastStatusWidgetEntry(date: entry.date, snapshot: entry.snapshot)
        }

        let reloadPolicy: TimelineReloadPolicy
        if let nextDate = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now) {
            reloadPolicy = .after(nextDate)
        } else {
            reloadPolicy = .never
        }

        completion(Timeline(entries: widgetEntries, policy: reloadPolicy))
    }
}

struct FastStatusWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FastingStateSnapshot
}

struct FastStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastStatusWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallFastWidgetView(snapshot: entry.snapshot, currentDate: entry.date)
        case .systemMedium:
            MediumFastWidgetView(snapshot: entry.snapshot, currentDate: entry.date)
        case .accessoryCircular:
            AccessoryCircularFastView(snapshot: entry.snapshot, currentDate: entry.date)
        case .accessoryRectangular:
            AccessoryRectangularFastView(snapshot: entry.snapshot, currentDate: entry.date)
        case .accessoryInline:
            AccessoryInlineFastView(snapshot: entry.snapshot, currentDate: entry.date)
        default:
            SmallFastWidgetView(snapshot: entry.snapshot, currentDate: entry.date)
        }
    }
}
