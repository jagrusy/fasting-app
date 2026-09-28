import SwiftUI

/// Card displaying the list of commitments and completion statistics for an active challenge.
struct ChallengeCommitmentsCard: View {
    let challenge: Challenge
    let currentNow: Date

    init(challenge: Challenge, currentNow: Date) {
        self.challenge = challenge
        self.currentNow = currentNow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Commitments")
                .font(.headline)

            ForEach(challenge.commitments) { commitment in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: categoryIcon(for: commitment.draft.category))
                            .foregroundStyle(SolsticeColors.solarAmber)

                        Text(commitment.draft.title)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        let completed = challenge.completedCount(for: commitment, through: currentNow)
                        let scheduled = challenge.scheduledDays(for: commitment, through: currentNow).count
                        Text("\(completed)/\(scheduled) days")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if let cue = commitment.draft.cue {
                        HStack(spacing: 4) {
                            Text("Anchor:")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(cue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let start = commitment.draft.smallStart {
                        HStack(spacing: 4) {
                            Text("First step:")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(start)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                if commitment.id != challenge.commitments.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func categoryIcon(for cat: String) -> String {
        switch cat {
        case "movement": return "figure.run"
        case "sleep": return "moon.stars.fill"
        case "food": return "leaf.fill"
        case "mindfulness": return "sparkles"
        case "routine": return "checklist"
        default: return "checkmark.circle"
        }
    }
}
