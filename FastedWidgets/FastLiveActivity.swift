import ActivityKit
import SwiftUI
import WidgetKit

struct FastLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastActivityAttributes.self) { context in
            FastLiveActivityLockScreenView(context: context)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(SolsticeColors.solarGold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Link(destination: DeepLink.fastTracker.url) {
                        FastGoalGaugeView(
                            progress: context.state.progress,
                            isCompleted: context.state.isGoalMet
                        ) {
                            Image(systemName: context.state.stage?.systemIcon ?? "flame.fill")
                                .font(.system(size: 13))
                        }
                        .frame(width: 54, height: 54)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: DeepLink.fastTracker.url) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(context.state.isGoalMet ? "Goal Met ✨" : "Target")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.state.goalDate, style: .time)
                                .font(.caption)
                                .fontWeight(.semibold)
                            StreakLabelView(streak: context.state.currentStreak)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        if context.state.isGoalMet {
                            FastElapsedText(
                                startDate: context.state.startDate,
                                goalDate: context.state.goalDate,
                                isCompleted: context.state.isGoalMet
                            )
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            EndFastButton()
                        } else {
                            // No button here, so the whole block can link out.
                            Link(destination: DeepLink.fastTracker.url) {
                                FastElapsedText(
                                    startDate: context.state.startDate,
                                    goalDate: context.state.goalDate,
                                    isCompleted: context.state.isGoalMet
                                )
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()

                                if let stage = context.state.stage {
                                    Text(stage.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } compactLeading: {
                // The Dynamic Island has no widgetURL equivalent for the whole presentation — each
                // non-button region that should open the app wraps itself in a Link instead.
                Link(destination: DeepLink.fastTracker.url) {
                    Image(systemName: context.state.stage?.systemIcon ?? "flame.fill")
                        .foregroundColor(SolsticeColors.solarAmber)
                }
            } compactTrailing: {
                Link(destination: DeepLink.fastTracker.url) {
                    FastElapsedText(
                        startDate: context.state.startDate,
                        goalDate: context.state.goalDate,
                        isCompleted: context.state.isGoalMet
                    )
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                }
            } minimal: {
                Link(destination: DeepLink.fastTracker.url) {
                    FastGoalGaugeView(
                        progress: context.state.progress,
                        isCompleted: context.state.isGoalMet
                    )
                }
            }
            .keylineTint(SolsticeColors.solarAmber)
        }
    }
}

struct FastLiveActivityLockScreenView: View {
    let context: ActivityViewContext<FastActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            FastGoalGaugeView(
                progress: context.state.progress,
                isCompleted: context.state.isGoalMet
            ) {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("Solstice")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.protocolType)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }

                FastElapsedText(
                    startDate: context.state.startDate,
                    goalDate: context.state.goalDate,
                    isCompleted: context.state.isGoalMet
                )
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

                if context.state.isGoalMet {
                    Text("Goal Achieved ✨")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(SolsticeColors.emeraldGlow)
                    EndFastButton()
                } else if let stage = context.state.stage {
                    Text("\(stage.title) · target \(context.state.goalDate, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
