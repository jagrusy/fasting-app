import SwiftUI
import WidgetKit

struct FastStreakWidget: Widget {
    let kind: String = "FastStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastStatusTimelineProvider()) { entry in
            FastStreakWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Fasting Streak")
        .description("Your current streak measured against your personal best.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct FastStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastStatusWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            StreakGaugeView(
                currentStreak: entry.snapshot.currentStreak,
                longestStreak: entry.snapshot.longestStreak
            )
        case .accessoryRectangular:
            StreakRectangularView(snapshot: entry.snapshot)
        default:
            StreakSmallView(snapshot: entry.snapshot)
        }
    }
}

struct StreakSmallView: View {
    let snapshot: FastingStateSnapshot

    var body: some View {
        VStack(spacing: 6) {
            WidgetHeaderView(snapshot: snapshot)

            StreakGaugeView(
                currentStreak: snapshot.currentStreak,
                longestStreak: snapshot.longestStreak
            )
            .frame(width: 62, height: 62)

            Text(snapshot.currentStreak == 1 ? "1 day streak" : "\(snapshot.currentStreak) day streak")
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if snapshot.longestStreak > 0 {
                Text("Best \(snapshot.longestStreak)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(2)
    }
}

struct StreakRectangularView: View {
    let snapshot: FastingStateSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("Streak")
                    .fontWeight(.bold)
            }
            .font(.caption2)

            Text("\(snapshot.currentStreak) of \(max(snapshot.longestStreak, snapshot.currentStreak))")
                .font(.headline)
                .monospacedDigit()

            Gauge(value: streakFraction, in: 0...1) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(SolsticeColors.solarFlame)
        }
    }

    private var streakFraction: Double {
        let best = max(snapshot.longestStreak, snapshot.currentStreak)
        guard best > 0 else { return 0 }
        return min(1.0, Double(snapshot.currentStreak) / Double(best))
    }
}
