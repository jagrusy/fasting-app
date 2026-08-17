import SwiftUI

public struct SettingsView: View {
    @ObservedObject var fastManager: FastManager
    @State private var notificationsEnabled: Bool = false
    @State private var schedule: NotificationSchedule = .default

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    public var body: some View {
        List {
            protocolSection
            NotificationSettingsSection(
                isEnabled: $notificationsEnabled,
                schedule: $schedule,
                onSave: { enabled, newSchedule in
                    fastManager.updateNotificationSchedule(enabled: enabled, schedule: newSchedule)
                }
            )
            aboutSection
        }
        .navigationTitle("Settings")
        .onAppear(perform: loadSettings)
    }

    private var protocolSection: some View {
        Section {
            NavigationLink {
                ProtocolPickerView(fastManager: fastManager)
            } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Protocol")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Text(fastManager.currentProtocol.name)
                                .font(.headline.weight(.semibold))

                            Text("(\(fastManager.currentProtocol.ratioString))")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }

                        Text(fastManager.currentProtocol.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("settings_protocol_navigation_link")
        } header: {
            Text("Fasting Plan")
        } footer: {
            Text("Select your preferred fasting window ratio. Changes apply to future fasts.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Privacy")
                Spacer()
                Text("100% On-Device")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About Fasted")
        } footer: {
            Text("Fasted is a private, lightweight fasting utility. No account or subscriptions required.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadSettings() {
        if let userSettings = fastManager.userSettings {
            notificationsEnabled = userSettings.notificationsEnabled
        }
        schedule = fastManager.notificationSchedule
    }
}
