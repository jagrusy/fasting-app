import SwiftUI

public struct NotificationSettingsSection: View {
    @Binding public var isEnabled: Bool
    @Binding public var schedule: NotificationSchedule
    public let onSave: (Bool, NotificationSchedule) -> Void

    private let dayNames = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
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
                .onChange(of: isEnabled) { newValue in
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
                .onChange(of: schedule.startReminderTime) { _ in
                    onSave(isEnabled, schedule)
                }
                .accessibilityIdentifier("start_reminder_picker")

                DatePicker(
                    "Eating Window Reminder",
                    selection: $schedule.endReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: schedule.endReminderTime) { _ in
                    onSave(isEnabled, schedule)
                }
                .accessibilityIdentifier("end_reminder_picker")

                VStack(alignment: .leading, spacing: 10) {
                    Text("ACTIVE DAYS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(dayNames, id: \.0) { day in
                            let isDaySelected = schedule.selectedDays.contains(day.0)
                            Button {
                                toggleDay(day.0)
                            } label: {
                                Text(day.1)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isDaySelected ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(isDaySelected ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("day_button_\(day.0)")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Reminders")
        } footer: {
            if isEnabled {
                Text("Receive reminders to start and break your fast at scheduled times.")
            }
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
