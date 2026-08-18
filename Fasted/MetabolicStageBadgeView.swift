import SwiftUI

public struct MetabolicStageBadgeView: View {
    public let stage: MetabolicStage
    public let onTap: () -> Void

    public init(stage: MetabolicStage, onTap: @escaping () -> Void) {
        self.stage = stage
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: stage.systemIcon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(stage.color)

                Text(stage.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(stage.timeRangeString)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(stage.color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(stage.color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("metabolic_stage_badge")
    }
}
