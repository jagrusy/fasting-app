import SwiftUI

/// Main Challenge overview tab showing active challenge, calendar progress, and management.
struct ChallengeTabView: View {
    @ObservedObject var challengeManager: ChallengeManager
    @ObservedObject var fastManager: FastManager
    @State private var showBuilder: Bool = false
    @State private var showPastChallenges: Bool = false
    @State private var showArchiveConfirmation: Bool = false
    @State private var showSettings: Bool = false

    init(challengeManager: ChallengeManager, fastManager: FastManager) {
        self.challengeManager = challengeManager
        self.fastManager = fastManager
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let challenge = challengeManager.activeChallenge {
                        activeChallengeContent(challenge)
                    } else {
                        idleContent
                    }
                }
                .padding()
            }
            .navigationTitle("Challenge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityIdentifier("challenge_tab_settings_button")
                }
            }
            .sheet(isPresented: $showBuilder) {
                ChallengeBuilderView(challengeManager: challengeManager)
            }
            .sheet(isPresented: $showPastChallenges) {
                PastChallengesView(challengeManager: challengeManager)
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
            .confirmationDialog(
                "Archive Challenge?",
                isPresented: $showArchiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Archive Challenge", role: .destructive) {
                    if let id = challengeManager.activeChallenge?.id {
                        do {
                            try challengeManager.archive(challengeID: id)
                        } catch {
                            challengeManager.errorMessage = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This ends your current challenge early. "
                     + "All past check-ins and progress remain safe in your history.")
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "flag.2.crossed.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(SolsticeColors.solarAmber)
                    .padding(.top, 24)

                Text("Build Your Challenge")
                    .font(.title2.weight(.bold))

                Text("Pair your fasting rhythm with simple, positive daily commitments "
                     + "like daily walks, hydration, or wind-down routines.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                showBuilder = true
            } label: {
                Label("Create a Challenge", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("challenge_create_button")

            if !challengeManager.archivedChallenges.isEmpty {
                Button {
                    showPastChallenges = true
                } label: {
                    Label("View Past Challenges", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                }
                .accessibilityIdentifier("challenge_view_past_button")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func activeChallengeContent(_ challenge: Challenge) -> some View {
        VStack(spacing: 20) {
            headerCard(challenge)
            ChallengeProgressGridCard(challenge: challenge, currentNow: challengeManager.now())
            ChallengeCommitmentsCard(challenge: challenge, currentNow: challengeManager.now())
            actionsSection
        }
    }

    private func headerCard(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.title2.weight(.bold))

                    if let reason = challenge.reason {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if let current = challengeManager.currentDayNumber,
                   let total = challengeManager.totalDays {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Day \(current) of \(total)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(SolsticeColors.solarAmber)
                    }
                    .accessibilityIdentifier("challenge_day_counter")
                }
            }

            ProgressView(value: challengeManager.dayProgressFraction)
                .tint(SolsticeColors.solarAmber)

            HStack {
                Text("Started \(dateFormatter.string(from: challenge.startDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Ends \(dateFormatter.string(from: challenge.endDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showBuilder = true
            } label: {
                Label("Start a New Challenge", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("challenge_replace_button")

            Button(role: .destructive) {
                showArchiveConfirmation = true
            } label: {
                Label("Archive Current Challenge", systemImage: "archivebox")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            .accessibilityIdentifier("challenge_archive_button")

            if !challengeManager.archivedChallenges.isEmpty {
                Button {
                    showPastChallenges = true
                } label: {
                    Text("View Past Challenges")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("challenge_view_past_button")
            }
        }
        .padding(.top, 4)
    }
}
