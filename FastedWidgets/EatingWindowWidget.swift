import SwiftUI
import WidgetKit

/// The other half of the day. On 16:8 the user is in the eating window a third of the time, and
/// every other surface treats that state as dead space.
struct EatingWindowWidget: Widget {
    let kind: String = "EatingWindowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastStatusTimelineProvider()) { entry in
            EatingWindowEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Eating Window")
        .description("Time left in your eating window before the next fast.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct EatingWindowEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastStatusWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                EatingWindowGaugeView(snapshot: entry.snapshot, currentDate: entry.date)
            case .accessoryRectangular:
                EatingWindowRectangularView(snapshot: entry.snapshot, currentDate: entry.date)
            default:
                EatingWindowSmallView(snapshot: entry.snapshot, currentDate: entry.date)
            }
        }
        .widgetURL(DeepLink.forWidgetTap(isFasting: entry.snapshot.isFasting).url)
    }
}

struct EatingWindowSmallView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        VStack(spacing: 6) {
            WidgetHeaderView(snapshot: snapshot)

            if let end = snapshot.eatingWindowEnd(), end > currentDate {
                EatingWindowGaugeView(snapshot: snapshot, currentDate: currentDate)
                    .frame(width: 60, height: 60)

                Text(end, style: .timer)
                    .font(.callout)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("until \(end, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Spacer()
                Text(snapshot.isFasting ? "Fasting" : "Window Closed")
                    .font(.headline)
                    .fontWeight(.bold)
                if !snapshot.isFasting {
                    StartFastButton()
                }
                Spacer()
            }
        }
        .padding(2)
    }
}

struct EatingWindowRectangularView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                Text("Eating Window")
                    .fontWeight(.bold)
            }
            .font(.caption2)

            if let end = snapshot.eatingWindowEnd(), end > currentDate {
                Text(end, style: .timer)
                    .font(.headline)
                    .monospacedDigit()

                Gauge(value: snapshot.eatingWindowProgress(at: currentDate) ?? 0, in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(SolsticeColors.tealGlow)
            } else {
                Text(snapshot.isFasting ? "Fasting now" : "Window closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
