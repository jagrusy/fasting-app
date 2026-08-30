import SwiftUI

public struct FastStartedCardView: View {
    public let fast: Fast
    public let now: Date
    /// Start time to display instead of the stored one while a ring drag is in progress — the
    /// drag isn't written to Core Data until release, so `fast.startDate` is stale until then.
    public let previewStartDate: Date?
    public let onSelectDayOffset: (Int) -> Void
    public let onSelectTime: () -> Void

    public init(
        fast: Fast,
        now: Date,
        previewStartDate: Date? = nil,
        onSelectDayOffset: @escaping (Int) -> Void,
        onSelectTime: @escaping () -> Void
    ) {
        self.fast = fast
        self.now = now
        self.previewStartDate = previewStartDate
        self.onSelectDayOffset = onSelectDayOffset
        self.onSelectTime = onSelectTime
    }

    public var body: some View {
        let startDate = previewStartDate ?? fast.startDate ?? now
        let isStartedYesterday = Calendar.current.isDateInYesterday(startDate)

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STARTED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    dateMenu(isStartedYesterday: isStartedYesterday)
                    timeButton(startDate: startDate)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                Text("GOAL TARGET")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                goalTargetView(startDate: startDate)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func dateMenu(isStartedYesterday: Bool) -> some View {
        Menu {
            Button("Today") { onSelectDayOffset(0) }
            Button("Yesterday") { onSelectDayOffset(-1) }
        } label: {
            HStack(spacing: 4) {
                Text(isStartedYesterday ? "Yesterday" : "Today")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityIdentifier("start_date_menu")
    }

    private func timeButton(startDate: Date) -> some View {
        Button(action: onSelectTime) {
            HStack(spacing: 4) {
                Text(formatTime(startDate))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "pencil")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityIdentifier("start_time_button")
    }

    private func goalTargetView(startDate: Date) -> some View {
        let targetDate = startDate.addingTimeInterval(fast.targetDuration)
        let calendar = Calendar.current

        let dayLabel: String?
        if calendar.isDateInTomorrow(targetDate) {
            dayLabel = "Tomorrow"
        } else if !calendar.isDate(targetDate, inSameDayAs: startDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            dayLabel = formatter.string(from: targetDate)
        } else {
            dayLabel = nil
        }

        return VStack(alignment: .trailing, spacing: 2) {
            if let label = dayLabel {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(formatTime(targetDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
        .padding(.vertical, dayLabel == nil ? 6 : 0)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
