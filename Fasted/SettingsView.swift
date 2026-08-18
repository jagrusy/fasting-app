import SwiftUI

public struct SettingsView: View {
    @ObservedObject var fastManager: FastManager
    @State private var notificationsEnabled: Bool = false
    @State private var schedule: NotificationSchedule = .default
    @State private var showEraseConfirmation: Bool = false
    @State private var showDisclaimer: Bool = false

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
            healthAndResourcesSection
            dataManagementSection
            aboutSection
        }
        .navigationTitle("Settings")
        .onAppear(perform: loadSettings)
        .sheet(isPresented: $showDisclaimer) {
            MedicalDisclaimerView()
        }
        .confirmationDialog(
            "Erase All Fasting Data?",
            isPresented: $showEraseConfirmation,
            titleVisibility: .visible,
            actions: {
                Button("Erase All Data", role: .destructive) {
                    fastManager.clearAllFastingData()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text(
                    "This will permanently delete all completed and active fasts, "
                    + "and reset your streaks. This cannot be undone."
                )
            }
        )
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

    private var healthAndResourcesSection: some View {
        Section {
            Button {
                showDisclaimer = true
            } label: {
                HStack {
                    Label("Medical Disclaimer & Safety", systemImage: "cross.case.fill")
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("settings_medical_disclaimer_button")

            if let hopkinsURL = URL(string: "https://www.hopkinsmedicine.org/health/wellness-and-prevention/intermittent-fasting-what-is-it-and-how-does-it-work") {
                Link(destination: hopkinsURL) {
                    Label("Johns Hopkins: Fasting Guide", systemImage: "arrow.up.right.square")
                }
                .accessibilityIdentifier("link_johns_hopkins")
            }

            if let harvardURL = URL(string: "https://www.health.harvard.edu/blog/intermittent-fasting-surprising-update-2018062914156") {
                Link(destination: harvardURL) {
                    Label("Harvard Health: Research Update", systemImage: "arrow.up.right.square")
                }
                .accessibilityIdentifier("link_harvard_health")
            }

            if let mayoURL = URL(string: "https://www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating/expert-answers/intermittent-fasting/faq-20441303") {
                Link(destination: mayoURL) {
                    Label("Mayo Clinic: Fasting FAQs", systemImage: "arrow.up.right.square")
                }
                .accessibilityIdentifier("link_mayo_clinic")
            }
        } header: {
            Text("Health & Evidence-Based Research")
        } footer: {
            Text(
                "Fasted is for general wellness tracking and does not provide medical advice. "
                + "Consult a physician before starting any fasting regimen."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showEraseConfirmation = true
            } label: {
                Label("Erase All Fasting Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .accessibilityIdentifier("erase_all_data_button")
        } header: {
            Text("Data Management")
        } footer: {
            Text("Permanently delete all historical fast records and reset your fasting streaks.")
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
