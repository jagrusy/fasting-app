import SwiftUI

public struct FastRowView: View {
    public let fast: Fast

    public init(fast: Fast) {
        self.fast = fast
    }

    private var startDate: Date {
        fast.startDate ?? Date()
    }

    private var endDate: Date {
        fast.endDate ?? Date()
    }

    private var elapsedSeconds: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    private var isCompletedGoal: Bool {
        fast.isCompleted || (elapsedSeconds >= fast.targetDuration)
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Status Icon badge
            ZStack {
                let badgeColor = isCompletedGoal ? Color.green : Color.orange
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: isCompletedGoal ? "checkmark.seal.fill" : "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isCompletedGoal ? Color.green : Color.orange)
            }

            // Fast details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(formatDuration(elapsedSeconds))
                        .font(.headline.weight(.bold))

                    Text(fast.protocolType ?? "16:8")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }

                Text(formatDateRange(start: startDate, end: endDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Completion percentage / target
            VStack(alignment: .trailing, spacing: 4) {
                let targetHours = Int((fast.targetDuration) / 3600)
                let pct = Int((elapsedSeconds / max(1, fast.targetDuration)) * 100)

                Text("\(pct)%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isCompletedGoal ? Color.green : Color.primary)

                Text("of \(targetHours)h goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fast_row_\(fast.id?.uuidString ?? "")")
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(0, interval) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dayStr = dayFormatter.string(from: start)
        let startTimeStr = timeFormatter.string(from: start)
        let endTimeStr = timeFormatter.string(from: end)

        return "\(dayStr) · \(startTimeStr) – \(endTimeStr)"
    }
}
