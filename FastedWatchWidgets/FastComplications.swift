import SwiftUI
import WidgetKit

@main
struct FastWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FastComplications()
        FastStageComplications()
    }
}

/// Separate complication so a watch face can carry goal progress and stage progress side by side —
/// at 14h into a 16h fast the goal gauge reads 88% while autophagy is still four hours out.
struct FastStageComplications: Widget {
    let kind: String = "FastStageComplications"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastWatchTimelineProvider()) { entry in
            FastStageComplicationEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Metabolic Stage")
        .description("Track progress toward your next metabolic stage.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

struct FastStageComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastWatchEntry

    var body: some View {
        switch family {
        case .accessoryCorner:
            let stage = entry.snapshot.currentStage(at: entry.date)
            Image(systemName: stage?.systemIcon ?? "sun.max.fill")
                .font(.title2)
                .foregroundColor(stage?.color ?? SolsticeColors.solarGold)
                .widgetLabel {
                    Gauge(value: entry.snapshot.stageProgress(at: entry.date) ?? 0, in: 0...1) {
                        EmptyView()
                    }
                    .tint(stage?.color ?? SolsticeColors.solarGold)
                }
        default:
            FastStageGaugeView(snapshot: entry.snapshot, currentDate: entry.date)
        }
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

        let nextDate = WidgetTimelineBuilder.nextReloadDate(entries: entries, now: now)
        completion(Timeline(entries: watchEntries, policy: .after(nextDate)))
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
