import SwiftUI

public struct FastMetricsCenterView: View {
    public let fast: Fast?
    public let currentProtocol: FastingProtocol
    public let progress: Double
    public let centerDisplayMode: CenterDisplayMode
    public let now: Date

    public init(
        fast: Fast?,
        currentProtocol: FastingProtocol,
        progress: Double,
        centerDisplayMode: CenterDisplayMode,
        now: Date
    ) {
        self.fast = fast
        self.currentProtocol = currentProtocol
        self.progress = progress
        self.centerDisplayMode = centerDisplayMode
        self.now = now
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
        let startDate = fast.startDate ?? now
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

    private func elapsedContent(elapsed: TimeInterval, targetDuration: TimeInterval, protocolType: String?) -> some View {
        VStack(spacing: 4) {
            Text(formatDuration(elapsed))
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
            let remainingText = remaining > 0 ? formatDuration(remaining) : "Goal Met!"
            Text(remainingText)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundStyle(remaining > 0 ? Color.primary : Color.green)
                .accessibilityIdentifier("remaining_time_text")

            let targetEndDate = startDate.addingTimeInterval(duration)
            Text("Goal: \(formatTime(targetEndDate))")
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

            Text("\(formatDuration(elapsed)) of \(formatGoal(targetDuration))")
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

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatGoal(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(max(0, duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
