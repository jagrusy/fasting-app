import SwiftUI

public struct FastMetricsCenterView: View {
    public let fast: Fast?
    public let currentProtocol: FastingProtocol
    public let progress: Double
    public let centerDisplayMode: CenterDisplayMode
    public let now: Date
    /// Start time to display instead of the stored one while a ring drag is in progress — the
    /// drag isn't written to Core Data until release, so `fast.startDate` is stale until then.
    public let previewStartDate: Date?

    public init(
        fast: Fast?,
        currentProtocol: FastingProtocol,
        progress: Double,
        centerDisplayMode: CenterDisplayMode,
        now: Date,
        previewStartDate: Date? = nil
    ) {
        self.fast = fast
        self.currentProtocol = currentProtocol
        self.progress = progress
        self.centerDisplayMode = centerDisplayMode
        self.now = now
        self.previewStartDate = previewStartDate
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let fast = fast {
                activeDisplay(fast: fast)
            } else {
                idleDisplay
            }
        }
    }

    private func activeDisplay(fast: Fast) -> some View {
        let startDate = previewStartDate ?? fast.startDate ?? now
        let elapsed = max(0, now.timeIntervalSince(startDate))
        let remaining = fast.targetDuration - elapsed

        return VStack(spacing: 6) {
            Text(centerDisplayMode.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            switch centerDisplayMode {
            case .elapsed:
                elapsedContent(elapsed: elapsed, targetDuration: fast.targetDuration, protocolType: fast.protocolType)
            case .remaining:
                remainingContent(startDate: startDate, duration: fast.targetDuration, remaining: remaining)
            case .percentage:
                percentageContent(elapsed: elapsed, targetDuration: fast.targetDuration)
            }

            Text("Tap to switch metric")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
    }

    private func elapsedContent(
        elapsed: TimeInterval,
        targetDuration: TimeInterval,
        protocolType: String?
    ) -> some View {
        VStack(spacing: 4) {
            Text(FastDurationFormatter.formatClock(elapsed))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary)
                .accessibilityIdentifier("elapsed_time_text")

            let ratioLabel = FastingProtocol.label(forTargetDuration: targetDuration, protocolType: protocolType)
            Text("\(Int(progress * 100))% · \(ratioLabel)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(progress >= 1.0 ? .green : .secondary)
                .accessibilityIdentifier("progress_percentage_text")
        }
    }

    private func remainingContent(startDate: Date, duration: TimeInterval, remaining: TimeInterval) -> some View {
        VStack(spacing: 4) {
            let remainingText = remaining > 0 ? FastDurationFormatter.formatClock(remaining) : "Goal Met!"
            Text(remainingText)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundStyle(remaining > 0 ? Color.primary : Color.green)
                .accessibilityIdentifier("remaining_time_text")

            let targetEndDate = startDate.addingTimeInterval(duration)
            Text("Goal: \(FastDurationFormatter.formatTime(targetEndDate))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func percentageContent(elapsed: TimeInterval, targetDuration: TimeInterval) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(progress * 100))%")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(progress >= 1.0 ? Color.green : Color.primary)
                .accessibilityIdentifier("percentage_display_text")

            let clock = FastDurationFormatter.formatClock(elapsed)
            let goal = FastDurationFormatter.formatDuration(targetDuration)
            Text("\(clock) of \(goal)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var idleDisplay: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .padding(.bottom, 4)

            Text(currentProtocol.ratioString)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(currentProtocol.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
