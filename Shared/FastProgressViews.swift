import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct FastLiveTimerView: View {
    public let startDate: Date
    public let goalDate: Date
    public let isCompleted: Bool

    public init(startDate: Date, goalDate: Date, isCompleted: Bool = false) {
        self.startDate = startDate
        self.goalDate = goalDate
        self.isCompleted = isCompleted
    }

    public var body: some View {
        FastElapsedText(startDate: startDate, goalDate: goalDate, isCompleted: isCompleted)
            .monospacedDigit()
            .fontWeight(.bold)
    }
}

/// Elapsed time that keeps ticking without waking the process.
///
/// `Text(timerInterval:)` clamps to its range, so past the goal a `start...goal` range freezes at
/// the goal duration — an overdue fast would sit at "16:00:00" forever. Past the goal we switch to
/// the open-ended `.timer` style, which counts up indefinitely and is equally reload-free.
public struct FastElapsedText: View {
    public let startDate: Date
    public let goalDate: Date
    public let isCompleted: Bool

    public init(startDate: Date, goalDate: Date, isCompleted: Bool) {
        self.startDate = startDate
        self.goalDate = goalDate
        self.isCompleted = isCompleted
    }

    public var body: some View {
        if isCompleted {
            Text(startDate, style: .timer)
        } else {
            Text(timerInterval: startDate...goalDate, countsDown: false)
        }
    }
}

/// Goal progress as a capacity gauge.
///
/// The value is fixed for the lifetime of a timeline entry — unlike `Text` and `ProgressView`,
/// `Gauge` has no `timerInterval` form that WidgetKit re-renders on its own. `WidgetTimelineBuilder`
/// compensates by spacing entries about a percent of the goal apart; pair this with a live
/// `FastElapsedText` wherever the exact time matters, so the digits keep ticking between entries.
public struct FastGoalGaugeView<Center: View>: View {
    public let progress: Double
    public let isCompleted: Bool
    private let center: Center

    public init(progress: Double, isCompleted: Bool, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.isCompleted = isCompleted
        self.center = center()
    }

    public var body: some View {
        Gauge(value: progress, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            center
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(isCompleted ? SolsticeColors.emeraldGlow : SolsticeColors.solarAmber)
    }
}

extension FastGoalGaugeView where Center == EmptyView {
    public init(progress: Double, isCompleted: Bool) {
        self.init(progress: progress, isCompleted: isCompleted) { EmptyView() }
    }
}

/// Progress through the current metabolic stage, tinted with that stage's colour.
public struct FastStageGaugeView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date
    public var showsIcon: Bool

    public init(snapshot: FastingStateSnapshot, currentDate: Date, showsIcon: Bool = true) {
        self.snapshot = snapshot
        self.currentDate = currentDate
        self.showsIcon = showsIcon
    }

    public var body: some View {
        let stage = snapshot.currentStage(at: currentDate)
        Gauge(value: snapshot.stageProgress(at: currentDate) ?? 0, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            if showsIcon {
                Image(systemName: stage?.systemIcon ?? "flame.fill")
                    .font(.system(size: 12))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(stage?.color ?? SolsticeColors.solarAmber)
    }
}

/// Current streak measured against the personal best.
///
/// A first-ever streak has no best to compare against yet, so the gauge fills against the current
/// value itself rather than dividing by zero.
public struct StreakGaugeView: View {
    public let currentStreak: Int
    public let longestStreak: Int

    public init(currentStreak: Int, longestStreak: Int) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
    }

    private var fraction: Double {
        let best = max(longestStreak, currentStreak)
        guard best > 0 else { return 0 }
        return min(1.0, Double(currentStreak) / Double(best))
    }

    public var body: some View {
        Gauge(value: fraction, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            Text("\(currentStreak)")
                .font(.system(size: 14, weight: .bold))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(SolsticeColors.solarFlame)
    }
}

public struct EatingWindowGaugeView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date

    public init(snapshot: FastingStateSnapshot, currentDate: Date) {
        self.snapshot = snapshot
        self.currentDate = currentDate
    }

    public var body: some View {
        if let progress = snapshot.eatingWindowProgress(at: currentDate) {
            Gauge(value: progress, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: "fork.knife")
                    .font(.system(size: 12))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(SolsticeColors.tealGlow)
        } else {
            Image(systemName: snapshot.isFasting ? "flame.fill" : "fork.knife")
                .font(.title3)
        }
    }
}

public struct FastProgressRingView: View {
    public let startDate: Date
    public let goalDate: Date
    public let isCompleted: Bool
    public var lineWidth: CGFloat

    public init(
        startDate: Date,
        goalDate: Date,
        isCompleted: Bool = false,
        lineWidth: CGFloat = 8
    ) {
        self.startDate = startDate
        self.goalDate = goalDate
        self.isCompleted = isCompleted
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ProgressView(
            timerInterval: startDate...goalDate,
            countsDown: false,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(isCompleted ? SolsticeColors.emeraldGlow : SolsticeColors.solarAmber)
    }
}

public struct FastStagePillView: View {
    public let stage: MetabolicStage?

    public init(stage: MetabolicStage?) {
        self.stage = stage
    }

    public var body: some View {
        if let stage = stage {
            HStack(spacing: 4) {
                Image(systemName: stage.systemIcon)
                    .font(.caption2)
                Text(stage.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.18))
            .clipShape(Capsule())
        }
    }
}

public struct AccessoryCircularFastView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date

    public init(snapshot: FastingStateSnapshot, currentDate: Date) {
        self.snapshot = snapshot
        self.currentDate = currentDate
    }

    public var body: some View {
        if snapshot.isFasting {
            FastGoalGaugeView(
                progress: snapshot.clampedProgress(at: currentDate),
                isCompleted: snapshot.isGoalMet(at: currentDate)
            ) {
                Image(systemName: snapshot.currentStage(at: currentDate)?.systemIcon ?? "flame.fill")
                    .font(.system(size: 12))
            }
        } else {
            Image(systemName: "sun.max.fill")
                .font(.title3)
        }
    }
}

public struct AccessoryRectangularFastView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date

    public init(snapshot: FastingStateSnapshot, currentDate: Date) {
        self.snapshot = snapshot
        self.currentDate = currentDate
    }

    public var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            let goal = start.addingTimeInterval(target)
            let stage = snapshot.currentStage(at: currentDate)
            let isGoalMet = snapshot.isGoalMet(at: currentDate)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let stage = stage {
                        Image(systemName: stage.systemIcon)
                        Text(stage.title)
                            .fontWeight(.bold)
                    } else {
                        Text("Fasting")
                            .fontWeight(.bold)
                    }
                }
                .font(.caption2)

                FastElapsedText(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                    .font(.headline)
                    .monospacedDigit()

                Gauge(value: snapshot.clampedProgress(at: currentDate), in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(isGoalMet ? SolsticeColors.emeraldGlow : SolsticeColors.solarAmber)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Solstice Fast")
                    .font(.caption)
                    .fontWeight(.bold)
                if let windowEnd = snapshot.eatingWindowEnd(), windowEnd > currentDate {
                    Text("Eating window ends \(windowEnd, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ready to Fast")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

public struct AccessoryInlineFastView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date

    public init(snapshot: FastingStateSnapshot, currentDate: Date) {
        self.snapshot = snapshot
        self.currentDate = currentDate
    }

    public var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            let goal = start.addingTimeInterval(target)
            let stage = snapshot.currentStage(at: currentDate)
            let stageName = stage?.title ?? "Fast"
            let isGoalMet = snapshot.isGoalMet(at: currentDate)
            ViewThatFits {
                HStack {
                    Image(systemName: stage?.systemIcon ?? "timer")
                    FastElapsedText(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                }
                Text("\(stageName)")
            }
        } else {
            Text("Solstice • Ready")
        }
    }
}

/// Corner complications invert the usual layout intuition: the view itself occupies a cramped
/// corner slot, while `widgetLabel` gets the long curved run along the bezel. Text of any real
/// length belongs in the label — an elapsed timer placed in the corner renders unreadably small.
/// A `Gauge` in the label is drawn as an arc following the face edge.
public struct AccessoryCornerFastView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date

    public init(snapshot: FastingStateSnapshot, currentDate: Date) {
        self.snapshot = snapshot
        self.currentDate = currentDate
    }

    public var body: some View {
        if snapshot.isFasting {
            let isGoalMet = snapshot.isGoalMet(at: currentDate)
            Image(systemName: snapshot.currentStage(at: currentDate)?.systemIcon ?? "flame.fill")
                .font(.title2)
                .foregroundColor(isGoalMet ? SolsticeColors.emeraldGlow : SolsticeColors.solarAmber)
                .widgetLabel {
                    Gauge(value: snapshot.clampedProgress(at: currentDate), in: 0...1) {
                        EmptyView()
                    }
                    .tint(isGoalMet ? SolsticeColors.emeraldGlow : SolsticeColors.solarAmber)
                }
        } else {
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundColor(SolsticeColors.solarGold)
                .widgetLabel("Solstice")
        }
    }
}
