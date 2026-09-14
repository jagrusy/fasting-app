import AppIntents
import SwiftUI
import WidgetKit

struct SmallFastWidgetView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            let goal = start.addingTimeInterval(target)
            let isGoalMet = snapshot.isGoalMet(at: currentDate)
            let stage = snapshot.currentStage(at: currentDate)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Solstice")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Spacer()
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

                Spacer()

                FastLiveTimerView(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                    .font(.title2)

                if let stage = stage {
                    FastStagePillView(stage: stage)
                }

                Spacer()

                if isGoalMet {
                    Text("Goal Met ✨")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(SolsticeColors.emeraldGlow)
                } else {
                    Text(goal, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(2)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(SolsticeColors.solarGold)
                    Text("Solstice")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Ready to Fast")
                    .font(.headline)
                    .fontWeight(.bold)

                if let proto = snapshot.protocolType {
                    Text("\(proto) Protocol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(intent: StartFastIntent()) {
                    Label("Start Fast", systemImage: "play.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(SolsticeColors.solarAmber)
            }
            .padding(2)
        }
    }
}

struct MediumFastWidgetView: View {
    let snapshot: FastingStateSnapshot
    let currentDate: Date

    var body: some View {
        if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
            let goal = start.addingTimeInterval(target)
            let isGoalMet = snapshot.isGoalMet(at: currentDate)
            let stage = snapshot.currentStage(at: currentDate)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Solstice")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        if let proto = snapshot.protocolType {
                            Text(proto)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    FastLiveTimerView(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                        .font(.title)

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
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    if let stage = stage {
                        HStack(spacing: 4) {
                            Image(systemName: stage.systemIcon)
                                .foregroundColor(SolsticeColors.solarAmber)
                            Text(stage.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Text(stage.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if snapshot.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(SolsticeColors.solarFlame)
                            Text("\(snapshot.currentStreak) day streak")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .padding(2)
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(SolsticeColors.solarGold)
                        Text("Solstice")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Ready to Fast")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let proto = snapshot.protocolType {
                        Text("\(proto) Protocol")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    if snapshot.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(SolsticeColors.solarFlame)
                            Text("\(snapshot.currentStreak) day streak")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }

                    Spacer()

                    Button(intent: StartFastIntent()) {
                        Label("Start Fast", systemImage: "play.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SolsticeColors.solarAmber)
                }
            }
            .padding(2)
        }
    }
}
