import SwiftUI

/// Lists archived and completed challenges.
struct PastChallengesView: View {
    @ObservedObject var challengeManager: ChallengeManager
    @Environment(\.dismiss) private var dismiss

    init(challengeManager: ChallengeManager) {
        self.challengeManager = challengeManager
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if challengeManager.archivedChallenges.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("No Past Challenges")
                            .font(.headline)
                        Text("Completed and archived challenges will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(challengeManager.archivedChallenges) { challenge in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(challenge.title)
                                    .font(.headline)
                                Spacer()
                                if challenge.endedAt != nil {
                                    Text("Archived")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                } else {
                                    Text("Completed")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }

                            if let reason = challenge.reason {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("\(challenge.dayCount) days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dateFormatter.string(from: challenge.startDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()
                                .padding(.vertical, 2)

                            ForEach(challenge.commitments) { commitment in
                                HStack {
                                    Text(commitment.draft.title)
                                        .font(.caption)
                                    Spacer()
                                    let completed = challenge.completedCount(
                                        for: commitment,
                                        through: challenge.endedAt ?? challenge.endDate
                                    )
                                    let scheduled = challenge.scheduledDays(
                                        for: commitment,
                                        through: challenge.endedAt ?? challenge.endDate
                                    ).count
                                    Text("\(completed)/\(scheduled) days")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("past_challenge_row_\(challenge.id.uuidString)")
                    }
                }
            }
            .navigationTitle("Past Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("past_challenges_done_button")
                }
            }
        }
    }
}
