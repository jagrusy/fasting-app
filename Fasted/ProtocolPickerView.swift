import SwiftUI

public struct ProtocolPickerView: View {
    @ObservedObject var fastManager: FastManager
    @Environment(\.dismiss) private var dismiss
    @State private var pendingProtocol: FastingProtocol?

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(FastingProtocol.presets) { proto in
                    let isSelected = fastManager.currentProtocol.ratioString == proto.ratioString
                    ProtocolCardView(
                        fastingProtocol: proto,
                        isSelected: isSelected,
                        onSelect: {
                            selectProtocol(proto)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("Fasting Protocol")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("protocol_picker_list")
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
                Text("You have a fast in progress. Retarget it to \(pendingProtocol?.ratioString ?? "")," +
                     " or keep it on its current goal and only use this protocol for future fasts.")
            }
        )
    }

    private func selectProtocol(_ proto: FastingProtocol) {
        guard fastManager.isFasting, fastManager.activeFast?.protocolType != proto.ratioString else {
            fastManager.updateSelectedProtocol(proto.ratioString)
            return
        }
        pendingProtocol = proto
    }

    private func applyToActiveFast(_ proto: FastingProtocol) {
        fastManager.updateSelectedProtocol(proto.ratioString)
        guard let fast = fastManager.activeFast, let startDate = fast.startDate else { return }
        fastManager.updateActiveFast(
            startDate: startDate,
            targetDuration: proto.fastingSeconds,
            protocolType: proto.ratioString
        )
    }
}
