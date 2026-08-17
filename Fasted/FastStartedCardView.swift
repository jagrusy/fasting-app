import SwiftUI

public struct FastStartedCardView: View {
    public let fast: Fast
    public let now: Date
    public let onSelectDayOffset: (Int) -> Void
    public let onSelectTime: () -> Void

    public init(
        fast: Fast,
        now: Date,
        onSelectDayOffset: @escaping (Int) -> Void,
        onSelectTime: @escaping () -> Void
    ) {
        self.fast = fast
        self.now = now
        self.onSelectDayOffset = onSelectDayOffset
        self.onSelectTime = onSelectTime
    }

    public var body: some View {
        let startDate = fast.startDate ?? now
        let isStartedYesterday = Calendar.current.isDateInYesterday(startDate)

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STARTED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    dateMenu(isStartedYesterday: isStartedYesterday)
                    timeButton(startDate: startDate)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("GOAL TARGET")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                goalTargetText(startDate: startDate)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func dateMenu(isStartedYesterday: Bool) -> some View {
        Menu {
            Button("Today") { onSelectDayOffset(0) }
            Button("Yesterday") { onSelectDayOffset(-1) }
        } label: {
            HStack(spacing: 4) {
                Text(isStartedYesterday ? "Yesterday" : "Today")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
        }
        .accessibilityIdentifier("start_date_menu")
    }

    private func timeButton(startDate: Date) -> some View {
        Button(action: onSelectTime) {
            HStack(spacing: 4) {
                Text(formatTime(startDate))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "pencil")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
        }
        .accessibilityIdentifier("start_time_button")
    }

    private func goalTargetText(startDate: Date) -> some View {
        let targetDate = startDate.addingTimeInterval(fast.targetDuration)
        let isTomorrow = Calendar.current.isDateInTomorrow(targetDate)
        let dayPrefix = isTomorrow ? "Tom, " : ""

        return Text("\(dayPrefix)\(formatTime(targetDate))")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.primary)
            .padding(.vertical, 6)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
