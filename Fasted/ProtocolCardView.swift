import SwiftUI

public struct ProtocolCardView: View {
    public let fastingProtocol: FastingProtocol
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(
        fastingProtocol: FastingProtocol,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.fastingProtocol = fastingProtocol
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Mini Proportion Visualizer Ring
                miniRingVisualizer

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(fastingProtocol.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.primary)

                        Text("(\(fastingProtocol.ratioString))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }

                    Text(fastingProtocol.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityIdentifier("protocol_selected_checkmark")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("protocol_card_\(fastingProtocol.ratioString)")
    }

    private var miniRingVisualizer: some View {
        let fastFraction = fastingProtocol.fastingHours / 24.0

        return ZStack {
            Circle()
                .stroke(Color.teal.opacity(0.35), lineWidth: 5)
                .frame(width: 38, height: 38)

            Circle()
                .trim(from: 0.0, to: CGFloat(fastFraction))
                .stroke(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 38, height: 38)
        }
    }
}
