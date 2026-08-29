import SwiftUI

public struct FastLiveTimerView: View {
    public let startDate: Date
    public let goalDate: Date
    public let isCompleted: Bool

    public init(startDate: Date, goalDate: Date, isCompleted: Bool = false) {
        self.startDate = startDate
        self.goalDate = goalDate
        self.isCompleted = isCompleted
    }

    public var body: some View {
        Text(timerInterval: startDate...goalDate, countsDown: false)
            .monospacedDigit()
            .fontWeight(.bold)
    }
}

public struct FastProgressRingView: View {
    public let startDate: Date
    public let goalDate: Date
    public let isCompleted: Bool
    public var lineWidth: CGFloat

    public init(
        startDate: Date,
        goalDate: Date,
        isCompleted: Bool = false,
        lineWidth: CGFloat = 8
    ) {
        self.startDate = startDate
        self.goalDate = goalDate
        self.isCompleted = isCompleted
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ProgressView(
            timerInterval: startDate...goalDate,
            countsDown: false,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(isCompleted ? SolsticeColors.emeraldGlow : SolsticeColors.solarAmber)
    }
}

public struct FastStagePillView: View {
    public let stage: MetabolicStage?

    public init(stage: MetabolicStage?) {
        self.stage = stage
    }

    public var body: some View {
        if let stage = stage {
            HStack(spacing: 4) {
                Image(systemName: stage.systemIcon)
                    .font(.caption2)

                Text(stage.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.18))
            .clipShape(Capsule())
        }
    }
}
