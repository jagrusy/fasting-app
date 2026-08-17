import SwiftUI

public struct StreakSummaryCardsView: View {
    public let streakInfo: StreakInfo

    public init(streakInfo: StreakInfo) {
        self.streakInfo = streakInfo
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                streakCard(
                    title: "CURRENT STREAK",
                    countText: "\(streakInfo.currentStreak)",
                    unitText: streakInfo.currentStreak == 1 ? "DAY" : "DAYS",
                    iconName: "flame.fill",
                    iconColor: .orange,
                    badgeColor: Color.orange.opacity(0.12),
                    identifier: "current_streak_label"
                )

                streakCard(
                    title: "BEST STREAK",
                    countText: "\(streakInfo.bestStreak)",
                    unitText: streakInfo.bestStreak == 1 ? "DAY" : "DAYS",
                    iconName: "trophy.fill",
                    iconColor: .yellow,
                    badgeColor: Color.yellow.opacity(0.12),
                    identifier: "best_streak_label"
                )
            }

            // Secondary metrics row
            HStack(spacing: 16) {
                metricItem(
                    title: "TOTAL FASTS",
                    value: "\(streakInfo.totalCompletedFasts)",
                    identifier: "total_fasts_count_label"
                )

                Divider().frame(height: 24)

                let totalHours = Int(streakInfo.totalFastingSeconds / 3600)
                metricItem(
                    title: "FASTED TIME",
                    value: "\(totalHours)h",
                    identifier: "total_fasts_time_label"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func streakCard(
        title: String,
        countText: String,
        unitText: String,
        iconName: String,
        iconColor: Color,
        badgeColor: Color,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: iconName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(iconColor)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(countText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier(identifier)

                Text(unitText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metricItem(title: String, value: String, identifier: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.primary)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity)
    }
}
