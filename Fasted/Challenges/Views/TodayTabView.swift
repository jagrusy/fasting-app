import SwiftUI

/// Today tab combining Fasting tracker with Today's Challenge commitments checklist.
struct TodayTabView: View {
    @ObservedObject var fastManager: FastManager
    @ObservedObject var challengeManager: ChallengeManager
    @State private var showSettings: Bool = false
    @State private var showBuilder: Bool = false

    init(fastManager: FastManager, challengeManager: ChallengeManager) {
        self.fastManager = fastManager
        self.challengeManager = challengeManager
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let challenge = challengeManager.activeChallenge {
                        todayCommitmentsCard(challenge)
                    } else {
                        startChallengeInviteCard
                    }

                    FastTrackerView(fastManager: fastManager)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityIdentifier("today_settings_button")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(fastManager: fastManager, challengeManager: challengeManager)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showSettings = false
                                }
                                .accessibilityIdentifier("settings_modal_done_button")
                            }
                        }
                }
            }
            .sheet(isPresented: $showBuilder) {
                ChallengeBuilderView(challengeManager: challengeManager)
            }
        }
    }

    private func todayCommitmentsCard(_ challenge: Challenge) -> some View {
        let today = challengeManager.now()
        let scheduled = challengeManager.scheduledCommitments(for: today)
        let allDone = challengeManager.allScheduledDone(for: today)

        return VStack(alignment: .leading, spacing: 14) {
            commitmentsHeader(challenge)

            if scheduled.isEmpty {
                Text("Rest day — no commitments scheduled for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(scheduled) { commitment in
                        commitmentRow(commitment, today: today)
                    }
                }

                if allDone {
                    allDoneBanner
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func commitmentsHeader(_ challenge: Challenge) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Commitments")
                    .font(.headline)
                Text(challenge.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let current = challengeManager.currentDayNumber,
               let total = challengeManager.totalDays {
                Text("Day \(current) of \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SolsticeColors.solarAmber)
                    .accessibilityIdentifier("today_day_counter")
            }
        }
    }

    private func commitmentRow(_ commitment: ChallengeCommitment, today: Date) -> some View {
        let isCompleted = challengeManager.isCompleted(commitmentID: commitment.id, on: today)

        return HStack(spacing: 12) {
            Button {
                toggleCommitment(commitment.id, on: today, currentlyCompleted: isCompleted)
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today_check_\(commitment.id.uuidString)")

            VStack(alignment: .leading, spacing: 2) {
                Text(commitment.draft.title)
                    .font(.subheadline.weight(isCompleted ? .regular : .medium))
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)

                if let cue = commitment.draft.cue {
                    Text(cue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var allDoneBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(SolsticeColors.solarAmber)
            Text("All commitments complete for today!")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SolsticeColors.solarAmber)
        }
        .padding(.top, 4)
        .accessibilityIdentifier("today_all_done_banner")
    }

    private var startChallengeInviteCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.2.crossed")
                .font(.title2)
                .foregroundStyle(SolsticeColors.solarAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ready for a Reset?")
                    .font(.subheadline.weight(.semibold))
                Text("Pair fasting with simple daily routines.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Start") {
                showBuilder = true
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .accessibilityIdentifier("today_start_challenge_button")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func toggleCommitment(_ commitmentID: UUID, on date: Date, currentlyCompleted: Bool) {
        let newStatus: ChallengeCheckInStatus? = currentlyCompleted ? nil : .done
        do {
            try challengeManager.checkIn(commitmentID: commitmentID, on: date, status: newStatus)
        } catch {
            challengeManager.errorMessage = error.localizedDescription
        }
    }
}
