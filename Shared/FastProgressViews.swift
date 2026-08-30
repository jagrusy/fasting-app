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
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            let goal = start.addingTimeInterval(target)
            ProgressView(
                timerInterval: start...goal,
                countsDown: false,
                label: { EmptyView() },
                currentValueLabel: {
                    if let stage = snapshot.currentStage(at: currentDate) {
                        Image(systemName: stage.systemIcon)
                            .font(.system(size: 12))
                    } else {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                    }
                }
            )
            .progressViewStyle(.circular)
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

                ProgressView(timerInterval: start...goal, countsDown: false)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Solstice Fast")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("Ready to Fast")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

public struct AccessoryCornerFastView: View {
    public let snapshot: FastingStateSnapshot
    public let currentDate: Date

    public init(snapshot: FastingStateSnapshot, currentDate: Date) {
        self.snapshot = snapshot
        self.currentDate = currentDate
    }

    public var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            let goal = start.addingTimeInterval(target)
            FastElapsedText(
                startDate: start,
                goalDate: goal,
                isCompleted: snapshot.isGoalMet(at: currentDate)
            )
                .widgetLabel {
                    if let stage = snapshot.currentStage(at: currentDate) {
                        Text(stage.shortTitle)
                    } else {
                        Text("Fast")
                    }
                }
        } else {
            Image(systemName: "sun.max.fill")
                .widgetLabel("Solstice")
        }
    }
}
