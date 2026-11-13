import SwiftUI

public struct NotificationSettingsSection: View {
    @Binding public var isEnabled: Bool
    @Binding public var schedule: NotificationSchedule
    public let onSave: (Bool, NotificationSchedule) -> Void

    private struct WeekdayOption {
        let id: Int
        let short: String
        let full: String
    }

    private let dayNames: [WeekdayOption] = [
        WeekdayOption(id: 1, short: "S", full: "Sunday"),
        WeekdayOption(id: 2, short: "M", full: "Monday"),
        WeekdayOption(id: 3, short: "T", full: "Tuesday"),
        WeekdayOption(id: 4, short: "W", full: "Wednesday"),
        WeekdayOption(id: 5, short: "T", full: "Thursday"),
        WeekdayOption(id: 6, short: "F", full: "Friday"),
        WeekdayOption(id: 7, short: "S", full: "Saturday")
    ]

    public init(
        isEnabled: Binding<Bool>,
        schedule: Binding<NotificationSchedule>,
        onSave: @escaping (Bool, NotificationSchedule) -> Void
    ) {
        self._isEnabled = isEnabled
        self._schedule = schedule
        self.onSave = onSave
    }

    public var body: some View {
        Section {
            Toggle("Daily Reminders", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    if newValue {
                        NotificationManager.shared.requestAuthorization { granted in
                            isEnabled = granted
                            onSave(granted, schedule)
                        }
                    } else {
                        onSave(false, schedule)
                    }
                }
                .accessibilityIdentifier("notifications_master_toggle")

            if isEnabled {
                DatePicker(
                    "Start Fast Reminder",
                    selection: $schedule.startReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: schedule.startReminderTime) {
                    onSave(isEnabled, schedule)
                }
                .accessibilityIdentifier("start_reminder_picker")

                VStack(alignment: .leading, spacing: 10) {

                    Text("ACTIVE DAYS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(dayNames, id: \.id) { day in
                            let isDaySelected = schedule.selectedDays.contains(day.id)
                            Button {
                                toggleDay(day.id)
                            } label: {
                                Text(day.short)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isDaySelected ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(isDaySelected ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(day.full)
                            .accessibilityAddTraits(isDaySelected ? .isSelected : [])
                            .accessibilityIdentifier("day_button_\(day.id)")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Toggle("Goal Reached Alert", isOn: $schedule.notifyOnGoalReached)
                .onChange(of: schedule.notifyOnGoalReached) {
                    onSave(isEnabled, schedule)
                }
                .accessibilityIdentifier("goal_reached_toggle")

            Toggle("Stage Transitions", isOn: $schedule.notifyOnStageChange)
                .onChange(of: schedule.notifyOnStageChange) {
                    onSave(isEnabled, schedule)
                }
                .accessibilityIdentifier("stage_transitions_toggle")
        } header: {
            Text("Reminders")
        } footer: {
            Text(
                "Schedule daily reminders to start fasting, or configure stage transition and " +
                "goal completion alerts for active fasts."
            )
        }

    }

    private func toggleDay(_ day: Int) {
        if schedule.selectedDays.contains(day) {
            // Keep at least 1 day selected
            if schedule.selectedDays.count > 1 {
                schedule.selectedDays.remove(day)
            }
        } else {
            schedule.selectedDays.insert(day)
        }
        onSave(isEnabled, schedule)
    }
}
