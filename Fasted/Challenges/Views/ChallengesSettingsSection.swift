import SwiftUI

/// Section in Settings for managing challenges toggle and active challenge status.
struct ChallengesSettingsSection: View {
    @ObservedObject var challengeManager: ChallengeManager
    @Binding var showBuilder: Bool

    init(challengeManager: ChallengeManager, showBuilder: Binding<Bool>) {
        self.challengeManager = challengeManager
        self._showBuilder = showBuilder
    }

    var body: some View {
        Section {
            Toggle(
                "Enable Challenges",
                isOn: $challengeManager.isChallengesEnabled
            )
            .accessibilityIdentifier("settings_challenges_toggle")

            if challengeManager.isChallengesEnabled {
                if let active = challengeManager.activeChallenge {
                    activeRow(active)
                } else {
                    Button {
                        showBuilder = true
                    } label: {
                        Label("Create a Challenge", systemImage: "plus")
                    }
                    .accessibilityIdentifier("settings_create_challenge_button")
                }
            }
        } header: {
            Text("Challenges & Daily Routine")
        } footer: {
            Text("Pair your fasting window with positive daily commitments. "
                 + "Disabling challenges hides challenge tabs but keeps all saved records.")
        }
    }

    private func activeRow(_ active: Challenge) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active: \(active.title)")
                    .font(.subheadline)
                if let current = challengeManager.currentDayNumber,
                   let total = challengeManager.totalDays {
                    Text("Day \(current) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
        }
        .accessibilityIdentifier("settings_active_challenge_row")
    }
}
