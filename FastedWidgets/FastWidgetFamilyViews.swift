import AppIntents
import SwiftUI
import WidgetKit

struct WidgetHeaderView: View {
    let snapshot: FastingStateSnapshot
    var showsSun: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if showsSun {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(SolsticeColors.solarGold)
            }
            Text("Solstice")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let proto = snapshot.protocolType {
                Text(proto)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

/// Idle-state footer: the eating window is the other half of a 16:8 day, so show how much of it is
/// left rather than a bare "Ready to Fast".
struct EatingWindowFooterView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if let end = snapshot.eatingWindowEnd(), end > currentDate {
            VStack(alignment: .leading, spacing: 1) {
                Text("Eating window")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(end, style: .timer)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
    }
}

struct StartFastButton: View {
    var fillsWidth: Bool = false

    var body: some View {
        Button(intent: StartFastIntent()) {
            Label("Start Fast", systemImage: "play.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(SolsticeColors.solarAmber)
    }
}

struct SmallFastWidgetView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            activeBody(start: start, target: target)
        } else {
            idleBody
        }
    }

    private func activeBody(start: Date, target: TimeInterval) -> some View {
        let goal = start.addingTimeInterval(target)
        let isGoalMet = snapshot.isGoalMet(at: currentDate)

        return VStack(spacing: 4) {
            WidgetHeaderView(snapshot: snapshot)

            FastGoalGaugeView(
                progress: snapshot.clampedProgress(at: currentDate),
                isCompleted: isGoalMet
            ) {
                Image(systemName: snapshot.currentStage(at: currentDate)?.systemIcon ?? "flame.fill")
                    .font(.system(size: 14))
            }
            .frame(width: 62, height: 62)

            FastLiveTimerView(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                .font(.callout)

            if isGoalMet {
                Text("Goal Met ✨")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(SolsticeColors.emeraldGlow)
            } else if let stage = snapshot.currentStage(at: currentDate) {
                Text(stage.shortTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(2)
    }

    private var idleBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeaderView(snapshot: snapshot, showsSun: true)
            Spacer()
            Text("Ready to Fast")
                .font(.headline)
                .fontWeight(.bold)
            EatingWindowFooterView(snapshot: snapshot, currentDate: currentDate)
            Spacer()
            StartFastButton()
        }
        .padding(2)
    }
}

struct MediumFastWidgetView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            activeBody(start: start, target: target)
        } else {
            idleBody
        }
    }

    private func activeBody(start: Date, target: TimeInterval) -> some View {
        let goal = start.addingTimeInterval(target)
        let isGoalMet = snapshot.isGoalMet(at: currentDate)

        return HStack(spacing: 14) {
            VStack(spacing: 6) {
                FastGoalGaugeView(
                    progress: snapshot.clampedProgress(at: currentDate),
                    isCompleted: isGoalMet
                ) {
                    Text("\(Int(snapshot.clampedProgress(at: currentDate) * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 66, height: 66)

                FastLiveTimerView(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                    .font(.footnote)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                WidgetHeaderView(snapshot: snapshot)
                stageDetail
                Spacer(minLength: 0)
                if isGoalMet {
                    Text("Goal Achieved ✨")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(SolsticeColors.emeraldGlow)
                } else {
                    HStack(spacing: 4) {
                        Text("Target:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(goal, style: .time)
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
                StreakLabelView(streak: snapshot.currentStreak)
            }
        }
        .padding(2)
    }

    @ViewBuilder
    private var stageDetail: some View {
        if let stage = snapshot.currentStage(at: currentDate) {
            HStack(spacing: 4) {
                Image(systemName: stage.systemIcon)
                    .foregroundColor(stage.color)
                Text(stage.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(stage.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var idleBody: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeaderView(snapshot: snapshot, showsSun: true)
                Spacer()
                Text("Ready to Fast")
                    .font(.title2)
                    .fontWeight(.bold)
                EatingWindowFooterView(snapshot: snapshot, currentDate: currentDate)
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                StreakLabelView(streak: snapshot.currentStreak)
                Spacer()
                StartFastButton(fillsWidth: true)
            }
        }
        .padding(2)
    }
}

struct StreakLabelView: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundColor(SolsticeColors.solarFlame)
                Text("\(streak) day streak")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct LargeFastWidgetView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        VStack(spacing: 12) {
            WidgetHeaderView(snapshot: snapshot, showsSun: !snapshot.isFasting)

            if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
                activeBody(start: start, target: target)
            } else {
                idleBody
            }

            Spacer(minLength: 0)
            stageTrack
        }
        .padding(2)
    }

    private func activeBody(start: Date, target: TimeInterval) -> some View {
        let goal = start.addingTimeInterval(target)
        let isGoalMet = snapshot.isGoalMet(at: currentDate)

        return HStack(spacing: 16) {
            FastGoalGaugeView(
                progress: snapshot.clampedProgress(at: currentDate),
                isCompleted: isGoalMet
            ) {
                Text("\(Int(snapshot.clampedProgress(at: currentDate) * 100))%")
                    .font(.system(size: 15, weight: .bold))
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                FastLiveTimerView(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                    .font(.title2)
                if isGoalMet {
                    Text("Goal Achieved ✨")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(SolsticeColors.emeraldGlow)
                } else {
                    Text("Target \(goal, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                StreakLabelView(streak: snapshot.currentStreak)
            }
            Spacer(minLength: 0)
        }
    }

    private var idleBody: some View {
        HStack(spacing: 16) {
            StreakGaugeView(
                currentStreak: snapshot.currentStreak,
                longestStreak: snapshot.longestStreak
            )
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to Fast")
                    .font(.title2)
                    .fontWeight(.bold)
                EatingWindowFooterView(snapshot: snapshot, currentDate: currentDate)
                StartFastButton()
            }
            Spacer(minLength: 0)
        }
    }

    private var stageTrack: some View {
        let active = snapshot.currentStage(at: currentDate)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Metabolic Stages")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(MetabolicStage.allCases) { stage in
                    let reached = active != nil && stage.rawValue <= (active?.rawValue ?? -1)
                    VStack(spacing: 3) {
                        Image(systemName: stage.systemIcon)
                            .font(.caption)
                            .foregroundColor(reached ? stage.color : .secondary.opacity(0.4))
                        Text(stage.shortTitle)
                            .font(.system(size: 8))
                            .foregroundStyle(reached ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
