import SwiftUI

public enum ProtocolPickerPresentation {
    case settings
    case quickSelect(
        title: String,
        subtitle: String? = nil,
        actionStyle: ProtocolCardActionStyle = .select,
        customButtonTitle: (Int) -> String = { "Start \($0)-Hour Fast" },
        selectedProtocolId: String? = nil,
        accessibilityIdPrefix: String = "start_menu_",
        onPick: (FastingProtocol) -> Void
    )
}

extension ProtocolPickerPresentation {
    struct QuickSelectOptions {
        let title: String
        let subtitle: String?
        let actionStyle: ProtocolCardActionStyle
        let customButtonTitle: (Int) -> String
        let selectedProtocolId: String?
        let accessibilityIdPrefix: String
        let onPick: (FastingProtocol) -> Void
    }

    var quickSelect: QuickSelectOptions? {
        guard case .quickSelect(
            let title,
            let subtitle,
            let actionStyle,
            let customButtonTitle,
            let selectedProtocolId,
            let accessibilityIdPrefix,
            let onPick
        ) = self else {
            return nil
        }
        return QuickSelectOptions(
            title: title,
            subtitle: subtitle,
            actionStyle: actionStyle,
            customButtonTitle: customButtonTitle,
            selectedProtocolId: selectedProtocolId,
            accessibilityIdPrefix: accessibilityIdPrefix,
            onPick: onPick
        )
    }
}

public struct ProtocolPickerView: View {
    @ObservedObject var fastManager: FastManager
    let presentation: ProtocolPickerPresentation
    @Environment(\.dismiss) private var dismiss
    @State private var pendingProtocol: FastingProtocol?
    @State private var showCustomFastSheet = false
    @State private var pickedCustomHours: Int?

    public init(fastManager: FastManager, presentation: ProtocolPickerPresentation = .settings) {
        self.fastManager = fastManager
        self.presentation = presentation
    }

    public var body: some View {
        Group {
            if let options = presentation.quickSelect {
                NavigationStack {
                    pickerScrollContent
                        .navigationTitle(options.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { dismiss() }
                            }
                        }
                }
                .presentationDetents([.fraction(0.75), .large])
            } else {
                pickerScrollContent
                    .navigationTitle("Fasting Protocol")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .accessibilityIdentifier("protocol_picker_list")
        .sheet(isPresented: $showCustomFastSheet, onDismiss: handleCustomSheetDismissed) {
            CustomFastSheetView(
                initialHours: fastManager.lastCustomFastHours ?? 36,
                confirmTitle: customConfirmTitle,
                onStart: { hours in
                    pickedCustomHours = hours
                    showCustomFastSheet = false
                },
                onCancel: {
                    pickedCustomHours = nil
                    showCustomFastSheet = false
                }
            )
        }
        .confirmationDialog(
            "Apply \(pendingProtocol?.ratioString ?? "") to Your Current Fast?",
            isPresented: Binding(
                get: { pendingProtocol != nil },
                set: { if !$0 { pendingProtocol = nil } }
            ),
            titleVisibility: .visible,
            actions: {
                Button("Apply to Current Fast") {
                    if let proto = pendingProtocol {
                        applyToActiveFast(proto)
                    }
                    pendingProtocol = nil
                }
                Button("Only Future Fasts") {
                    if let proto = pendingProtocol {
                        fastManager.updateSelectedProtocol(proto.ratioString)
                    }
                    pendingProtocol = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingProtocol = nil
                }
            },
            message: {
                let label = pendingProtocol?.displayTitle ?? ""
                Text("You have a fast in progress. Retarget it to \(label)," +
                     " or keep it on its current goal and only use this plan for future fasts.")
            }
        )
    }

    private var pickerScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompact ? 14 : 16) {
                if let subtitle = presentation.quickSelect?.subtitle {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(SolsticeColors.solarAmber)
                            .accessibilityHidden(true)
                        Text(subtitle)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("quick_select_subtitle")
                    }
                    .padding(.horizontal, 4)
                }

                sectionGroup(title: "Daily", protocols: FastingProtocol.presets)
                sectionGroup(title: "Extended", protocols: FastingProtocol.extendedPresets)
                customSectionGroup
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isCompact ? 12 : 16)
        }
    }

    @ViewBuilder
    private func sectionGroup(title: String, protocols: [FastingProtocol]) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            sectionHeader(title)

            if isCompact {
                LazyVGrid(columns: compactColumns, spacing: 10) {
                    ForEach(protocols) { proto in
                        protocolCard(for: proto)
                    }
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(protocols) { proto in
                        protocolCard(for: proto)
                    }
                }
            }
        }
    }

    private var customSectionGroup: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            sectionHeader("Custom")

            if isCompact {
                LazyVGrid(columns: compactColumns, spacing: 10) {
                    if let lastCustom = lastCustomProtocol {
                        protocolCard(
                            for: lastCustom,
                            overrideIdentifier: "\(accessibilityIdPrefix)custom_last"
                        )
                    }
                    customActionCard
                }
            } else {
                LazyVStack(spacing: 12) {
                    if let lastCustom = lastCustomProtocol {
                        protocolCard(for: lastCustom)
                    }
                    customActionCard
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func protocolCard(
        for proto: FastingProtocol,
        overrideIdentifier: String? = nil
    ) -> some View {
        let card = ProtocolCardView(
            fastingProtocol: proto,
            isSelected: activeSelectionId == proto.ratioString,
            isCompact: isCompact,
            actionStyle: presentation.quickSelect?.actionStyle ?? .select,
            accessibilityIdPrefix: accessibilityIdPrefix,
            onSelect: { handleSelection(proto) }
        )
        if let overrideIdentifier {
            card.accessibilityIdentifier(overrideIdentifier)
        } else {
            card
        }
    }

    private var customActionCard: some View {
        ProtocolCustomActionCardView(
            isCompact: isCompact,
            accessibilityId: "\(accessibilityIdPrefix)custom",
            onTap: { showCustomFastSheet = true }
        )
    }

    private var compactColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var isCompact: Bool { presentation.quickSelect != nil }
    private var accessibilityIdPrefix: String { presentation.quickSelect?.accessibilityIdPrefix ?? "protocol_card_" }

    private var activeSelectionId: String {
        presentation.quickSelect?.selectedProtocolId ?? fastManager.currentProtocol.ratioString
    }

    private var customConfirmTitle: (Int) -> String {
        presentation.quickSelect?.customButtonTitle ?? { "Select \($0)-Hour Plan" }
    }

    private var lastCustomProtocol: FastingProtocol? {
        guard let lastCustom = fastManager.lastCustomFastHours,
              !FastingProtocol.extendedPresets.contains(where: { Int($0.fastingHours) == lastCustom }) else {
            return nil
        }
        return FastingProtocol.fixedLength(hours: lastCustom)
    }

    private func handleSelection(_ proto: FastingProtocol) {
        if let quickSelect = presentation.quickSelect {
            quickSelect.onPick(proto)
            dismiss()
        } else {
            selectProtocol(proto)
        }
    }

    private func handleCustomSheetDismissed() {
        guard let hours = pickedCustomHours else { return }
        pickedCustomHours = nil
        fastManager.rememberCustomFastHours(hours)
        let proto = FastingProtocol.fixedLength(hours: hours)
        handleSelection(proto)
    }

    private func selectProtocol(_ proto: FastingProtocol) {
        guard fastManager.isFasting, fastManager.activeFast?.protocolType != proto.ratioString else {
            fastManager.updateSelectedProtocol(proto.ratioString)
            return
        }
        pendingProtocol = proto
    }

    private func applyToActiveFast(_ proto: FastingProtocol) {
        fastManager.updateSelectedProtocol(proto.ratioString, retargetActiveFast: true)
    }
}
