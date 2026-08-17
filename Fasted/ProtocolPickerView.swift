import SwiftUI

public struct ProtocolPickerView: View {
    @ObservedObject var fastManager: FastManager
    @Environment(\.dismiss) private var dismiss

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
                            fastManager.updateSelectedProtocol(proto.ratioString)
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
    }
}
