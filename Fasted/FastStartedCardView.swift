import SwiftUI

public struct FastStartedCardView: View {
    @ObservedObject public var fast: Fast
    public let now: Date
    /// Start time to display instead of the stored one while a ring drag is in progress — the
    /// drag isn't written to Core Data until release, so `fast.startDate` is stale until then.
    public let previewStartDate: Date?
    public let effectiveTargetDuration: TimeInterval?
    public let onSelectDayOffset: (Int) -> Void
    public let onSelectTime: () -> Void
    public let onExtendOneHour: (() -> Void)?
    public let onChangeGoal: (() -> Void)?

    public init(
        fast: Fast,
        now: Date,
        previewStartDate: Date? = nil,
        effectiveTargetDuration: TimeInterval? = nil,
        onSelectDayOffset: @escaping (Int) -> Void,
        onSelectTime: @escaping () -> Void,
        onExtendOneHour: (() -> Void)? = nil,
        onChangeGoal: (() -> Void)? = nil
    ) {
        self.fast = fast
        self.now = now
        self.previewStartDate = previewStartDate
        self.effectiveTargetDuration = effectiveTargetDuration
        self.onSelectDayOffset = onSelectDayOffset
        self.onSelectTime = onSelectTime
        self.onExtendOneHour = onExtendOneHour
        self.onChangeGoal = onChangeGoal
    }

    public var body: some View {
        let startDate = previewStartDate ?? fast.startDate ?? now

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STARTED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    dateMenu(startDate: startDate)
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

    private func dateMenu(startDate: Date) -> some View {
        Menu {
            Button("Today") { onSelectDayOffset(0) }
            Button("Yesterday") { onSelectDayOffset(-1) }
            Button(relativeDayOptionTitle(daysAgo: 2)) { onSelectDayOffset(-2) }
            Button(relativeDayOptionTitle(daysAgo: 3)) { onSelectDayOffset(-3) }
        } label: {
            HStack(spacing: 4) {
                Text(FastDurationFormatter.formatRelativeDay(startDate, now: now))
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

    private func relativeDayOptionTitle(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return FastDurationFormatter.formatRelativeDay(target, now: now, calendar: calendar)
    }

    private func timeButton(startDate: Date) -> some View {
        Button(action: onSelectTime) {
            HStack(spacing: 4) {
                Text(FastDurationFormatter.formatTime(startDate))
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

    @ViewBuilder
    private func goalTargetView(startDate: Date) -> some View {
        let targetDuration = effectiveTargetDuration ?? fast.targetDuration
        let targetDate = startDate.addingTimeInterval(targetDuration)
        let dayLabel = FastDurationFormatter.formatRelativeDay(targetDate, now: now)
        let timeLabel = FastDurationFormatter.formatTime(targetDate)

        if onExtendOneHour != nil || onChangeGoal != nil {
            goalTargetMenu(dayLabel: dayLabel, timeLabel: timeLabel)
        } else {
            goalTargetStaticLabel(dayLabel: dayLabel, timeLabel: timeLabel)
        }
    }

    private func goalTargetMenu(dayLabel: String, timeLabel: String) -> some View {
        Menu {
            if let onExtendOneHour {
                Button(action: onExtendOneHour) {
                    Label("Extend +1 Hour", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("extend_fast_one_hour_button")
            }

            if let onChangeGoal {
                Button(action: onChangeGoal) {
                    Label("Change Fast Goal…", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("change_fast_goal_button")
            }
        } label: {
            HStack(spacing: 5) {
                goalTargetStaticLabel(dayLabel: dayLabel, timeLabel: timeLabel)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
        }
        .accessibilityIdentifier("goal_target_menu")
    }

    private func goalTargetStaticLabel(dayLabel: String, timeLabel: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(dayLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(timeLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
