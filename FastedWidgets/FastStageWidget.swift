import SwiftUI
import WidgetKit

/// Progress toward the *next* metabolic stage rather than the goal.
///
/// The goal gauge can't answer "how close am I to autophagy?" — at 14h into a 16h fast it reads 88%
/// while autophagy is still four hours out.
struct FastStageWidget: Widget {
    let kind: String = "FastStageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastStatusTimelineProvider()) { entry in
            FastStageWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Metabolic Stage")
        .description("See how close you are to your next metabolic stage.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct FastStageWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FastStatusWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                FastStageGaugeView(snapshot: entry.snapshot, currentDate: entry.date)
            case .accessoryRectangular:
                StageRectangularView(snapshot: entry.snapshot, currentDate: entry.date)
            default:
                StageSmallView(snapshot: entry.snapshot, currentDate: entry.date)
            }
        }
        .widgetURL(DeepLink.forWidgetTap(isFasting: entry.snapshot.isFasting).url)
    }
}

struct StageSmallView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        VStack(spacing: 6) {
            WidgetHeaderView(snapshot: snapshot, showsSun: !snapshot.isFasting)

            if snapshot.isFasting, let stage = snapshot.currentStage(at: currentDate) {
                FastStageGaugeView(snapshot: snapshot, currentDate: currentDate)
                    .frame(width: 60, height: 60)

                Text(stage.title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                NextStageLabelView(snapshot: snapshot, currentDate: currentDate)
            } else {
                Spacer()
                Text("Not Fasting")
                    .font(.headline)
                EatingWindowFooterView(snapshot: snapshot, currentDate: currentDate)
                Spacer()
            }
        }
        .padding(2)
    }
}

struct StageRectangularView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if snapshot.isFasting, let stage = snapshot.currentStage(at: currentDate) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: stage.systemIcon)
                    Text(stage.title)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
                .font(.caption2)

                NextStageLabelView(snapshot: snapshot, currentDate: currentDate)

                Gauge(value: snapshot.stageProgress(at: currentDate) ?? 0, in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(stage.color)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Solstice")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("Not Fasting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NextStageLabelView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if let next = snapshot.nextStageBoundary(at: currentDate) {
            Text("\(next.stage.shortTitle) in \(next.date, style: .timer)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("Final stage")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
