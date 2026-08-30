import SwiftUI

struct WatchRootView: View {
    @ObservedObject var coordinator = WatchSessionCoordinator.shared
    @State private var currentDate = Date()

    var body: some View {
        ScrollView {
            let snapshot = coordinator.snapshot
            if snapshot.isFasting, let start = snapshot.startDate, let target = snapshot.targetDuration {
                let goal = start.addingTimeInterval(target)
                let isGoalMet = snapshot.isGoalMet(at: currentDate)
                let stage = snapshot.currentStage(at: currentDate)

                VStack(spacing: 8) {
                    HStack {
                        if let proto = snapshot.protocolType {
                            Text(proto)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if snapshot.currentStreak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(SolsticeColors.solarFlame)
                                Text("\(snapshot.currentStreak)")
                            }
                            .font(.caption2)
                            .fontWeight(.bold)
                        }
                    }

                    FastLiveTimerView(startDate: start, goalDate: goal, isCompleted: isGoalMet)
                        .font(.title2)

                    if let stage = stage {
                        FastStagePillView(stage: stage)
                    }

                    if isGoalMet {
                        Text("Goal Met ✨")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(SolsticeColors.emeraldGlow)
                    }

                    Button(role: .destructive) {
                        coordinator.endFast()
                    } label: {
                        Text("End Fast")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .tint(SolsticeColors.solarFlame)
                    .padding(.top, 4)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundColor(SolsticeColors.solarGold)

                    Text("Ready to Fast")
                        .font(.headline)
                        .fontWeight(.bold)

                    if let proto = snapshot.protocolType {
                        Text("\(proto) Protocol")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        let proto = FastingProtocol.from(
                            protocolType: snapshot.protocolType ?? FastingProtocol.default.ratioString
                        )
                        coordinator.startFast(
                            startDate: Date(),
                            duration: proto.fastingSeconds,
                            protocolType: proto.ratioString
                        )
                    } label: {
                        Label("Start Fast", systemImage: "play.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SolsticeColors.solarAmber)
                }
                .padding(.horizontal)
            }
        }
    }
}
