import SwiftUI

public struct MetabolicStagesSheetView: View {
    public let currentStage: MetabolicStage?
    public let elapsedSeconds: TimeInterval
    @Environment(\.dismiss) private var dismiss

    public init(currentStage: MetabolicStage?, elapsedSeconds: TimeInterval) {
        self.currentStage = currentStage
        self.elapsedSeconds = elapsedSeconds
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    stagesTimeline
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Metabolic Fasting Stages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("stages_done_button")
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("The Science of Fasting", systemImage: "flame.circle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text(
                "As you fast, your metabolism transitions through predictable biological milestones, "
                + "from clearing glucose to burning fat and activating cellular renewal (autophagy)."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var stagesTimeline: some View {
        VStack(spacing: 12) {
            ForEach(MetabolicStage.allCases) { stage in
                stageCard(stage)
            }
        }
    }

    private func stageCard(_ stage: MetabolicStage) -> some View {
        let isCurrent = currentStage == stage
        let isPassed = (currentStage?.rawValue ?? -1) > stage.rawValue

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isPassed ? "checkmark.circle.fill" : stage.systemIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isPassed ? Color.green : stage.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)

                    Text(stage.timeRangeString)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isCurrent {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(stage.color)
                        .clipShape(Capsule())
                } else if isPassed {
                    Text("COMPLETED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            Text(stage.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(14)
        .background(isCurrent ? stage.color.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCurrent ? stage.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}
