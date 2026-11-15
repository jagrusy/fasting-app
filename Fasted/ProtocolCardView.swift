import SwiftUI

public struct ProtocolCardView: View {
    public let fastingProtocol: FastingProtocol
    public let isSelected: Bool
    public let isCompact: Bool
    public let accessibilityIdPrefix: String
    public let onSelect: () -> Void

    public init(
        fastingProtocol: FastingProtocol,
        isSelected: Bool,
        isCompact: Bool = false,
        accessibilityIdPrefix: String = "protocol_card_",
        onSelect: @escaping () -> Void
    ) {
        self.fastingProtocol = fastingProtocol
        self.isSelected = isSelected
        self.isCompact = isCompact
        self.accessibilityIdPrefix = accessibilityIdPrefix
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            if isCompact {
                compactContent
            } else {
                standardContent
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(accessibilityIdPrefix)\(fastingProtocol.ratioString)")
    }

    private var standardContent: some View {
        HStack(spacing: 16) {
            miniRingVisualizer(size: 38, lineWidth: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(fastingProtocol.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.primary)

                    if !fastingProtocol.isExtendedPreset {
                        Text("(\(fastingProtocol.ratioString))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isSelected ? SolsticeColors.solarAmber : Color.secondary)
                    }
                }

                Text(fastingProtocol.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(SolsticeColors.solarAmber)
                    .accessibilityIdentifier("protocol_selected_checkmark")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var compactContent: some View {
        HStack(spacing: 10) {
            miniRingVisualizer(size: 28, lineWidth: 3.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(fastingProtocol.ratioString)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(fastingProtocol.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(SolsticeColors.solarAmber)
                    .accessibilityIdentifier("protocol_selected_checkmark")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? SolsticeColors.solarAmber.opacity(0.12) : Color(.secondarySystemBackground))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? SolsticeColors.solarAmber : Color.clear, lineWidth: 1.5)
    }

    private func miniRingVisualizer(size: CGFloat, lineWidth: CGFloat) -> some View {
        let fastFraction = min(max(fastingProtocol.fastingHours / 24.0, 0), 1)

        return ZStack {
            if fastingProtocol.hasEatingWindow {
                Circle()
                    .stroke(SolsticeColors.tealGlow.opacity(0.35), lineWidth: lineWidth)
                    .frame(width: size, height: size)
            }

            Circle()
                .trim(from: 0.0, to: CGFloat(fastFraction))
                .stroke(
                    SolsticeColors.solarGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
    }
}

/// Action card matching `ProtocolCardView` styling for opening custom duration selection.
struct ProtocolCustomActionCardView: View {
    let isCompact: Bool
    let accessibilityId: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: isCompact ? 10 : 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: isCompact ? 15 : 18, weight: .semibold))
                    .foregroundStyle(SolsticeColors.solarAmber)
                    .frame(width: isCompact ? 28 : 38, height: isCompact ? 28 : 38)
                    .background(SolsticeColors.solarAmber.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom…")
                        .font(isCompact ? .subheadline.weight(.bold) : .headline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Text("12–72 hours")
                        .font(isCompact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if !isCompact {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 10 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }
}
