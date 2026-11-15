import SwiftUI

public enum ProtocolPickerPresentation {
    case settings
    case quickSelect(
        title: String,
        customButtonTitle: (Int) -> String = { "Start \($0)-Hour Fast" },
        selectedProtocolId: String? = nil,
        accessibilityIdPrefix: String = "start_menu_",
        onPick: (FastingProtocol) -> Void
    )
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
            switch presentation {
            case .settings:
                pickerScrollContent
                    .navigationTitle("Fasting Protocol")
                    .navigationBarTitleDisplayMode(.inline)
            case .quickSelect(let title, _, _, _, _):
                NavigationStack {
                    pickerScrollContent
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { dismiss() }
                            }
                        }
                }
                .presentationDetents([.fraction(0.75), .large])
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

    private var isCompact: Bool {
        if case .quickSelect = presentation { return true }
        return false
    }

    private var accessibilityIdPrefix: String {
        if case .quickSelect(_, _, _, let prefix, _) = presentation {
            return prefix
        }
        return "protocol_card_"
    }

    private var activeSelectionId: String {
        if case .quickSelect(_, _, let overrideId, _, _) = presentation,
           let overrideId {
            return overrideId
        }
        return fastManager.currentProtocol.ratioString
    }

    private var customConfirmTitle: (Int) -> String {
        if case .quickSelect(_, let titleBuilder, _, _, _) = presentation {
            return titleBuilder
        }
        return { "Select \($0)-Hour Plan" }
    }

    private var lastCustomProtocol: FastingProtocol? {
        guard let lastCustom = fastManager.lastCustomFastHours,
              !FastingProtocol.extendedPresets.contains(where: { Int($0.fastingHours) == lastCustom }) else {
            return nil
        }
        return FastingProtocol.fixedLength(hours: lastCustom)
    }

    private func handleSelection(_ proto: FastingProtocol) {
        switch presentation {
        case .settings:
            selectProtocol(proto)
        case .quickSelect(_, _, _, _, let onPick):
            onPick(proto)
            dismiss()
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
