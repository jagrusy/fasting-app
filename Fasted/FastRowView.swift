import SwiftUI

public struct FastRowView: View {
    @ObservedObject public var fast: Fast

    public init(fast: Fast) {
        self.fast = fast
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Status Icon badge
            ZStack {
                let badgeColor = fast.isGoalMet ? Color.green : Color.orange
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: fast.isGoalMet ? "checkmark.seal.fill" : "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(fast.isGoalMet ? Color.green : Color.orange)
            }

            // Fast details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(fast.formattedDuration)
                        .font(.headline.weight(.bold))

                    Text(FastingProtocol.label(forTargetDuration: fast.targetDuration, protocolType: fast.protocolType))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }

                Text(fast.formattedDateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Completion percentage / target
            VStack(alignment: .trailing, spacing: 4) {
                let pct = Int(fast.progress * 100)

                Text("\(pct)%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(fast.isGoalMet ? Color.green : Color.primary)

                Text("of \(fast.formattedGoal) goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fast_row_\(fast.id?.uuidString ?? "")")
    }
}
