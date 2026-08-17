import SwiftUI

public struct FastTrackerView: View {
    @ObservedObject var fastManager: FastManager
    @State private var showStopConfirmation: Bool = false
    @State private var showDialEditor: Bool = false

    @State private var editableStartDate: Date = Date()
    @State private var editableTargetDuration: TimeInterval = 57600

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0)) { context in
            let now = context.date
            VStack(spacing: 28) {
                // Header status
                VStack(spacing: 6) {
                    Text(fastManager.isFasting ? "Current Fast" : "Ready to Fast")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    let statusTitle = fastManager.isFasting
                        ? "Fasting in Progress"
                        : "\(fastManager.currentProtocol.name) (\(fastManager.currentProtocol.ratioString))"

                    Text(statusTitle)
                        .font(.title2.weight(.bold))
                        .accessibilityIdentifier("fast_status_header")
                }
                .padding(.top, 16)

                // Main Circular Progress Display (Tap to Edit)
                ZStack {
                    let progress = calculateProgress(at: now)

                    ProgressRingView(
                        progress: progress,
                        isFasting: fastManager.isFasting,
                        ringWidth: 24
                    )
                    .frame(width: 280, height: 280)

                    // Inner Timer / Idle Content
                    VStack(spacing: 8) {
                        if let fast = fastManager.activeFast {
                            let startDate = fast.startDate ?? now
                            let elapsed = max(0, now.timeIntervalSince(startDate))

                            Text("ELAPSED")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(formatDuration(elapsed))
                                .font(.system(size: 38, weight: .bold, design: .monospaced))
                                .contentTransition(.numericText())
                                .accessibilityIdentifier("elapsed_time_text")

                            Text("\(Int(progress * 100))%")
                                .font(.headline.weight(.medium))
                                .foregroundStyle(progress >= 1.0 ? .green : .secondary)
                                .accessibilityIdentifier("progress_percentage_text")

                            let remaining = fast.targetDuration - elapsed
                            if remaining > 0 {
                                Text("\(formatDuration(remaining)) remaining")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Goal Completed!")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        } else {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.orange)
                                .padding(.bottom, 4)

                            Text(fastManager.currentProtocol.ratioString)
                                .font(.system(size: 32, weight: .bold, design: .rounded))

                            Text(fastManager.currentProtocol.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                }
                .contentShape(Circle())
                .onTapGesture {
                    if fastManager.isFasting, let fast = fastManager.activeFast {
                        editableStartDate = fast.startDate ?? now
                        editableTargetDuration = fast.targetDuration
                        showDialEditor = true
                    }
                }
                .accessibilityIdentifier("progress_ring_tap_target")
                .padding(.vertical, 8)

                // Fast details info card (when active)
                if let fast = fastManager.activeFast {
                    let startDate = fast.startDate ?? now
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Started")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatTime(startDate))
                                .font(.subheadline.weight(.semibold))
                        }

                        Divider()
                            .frame(height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target End")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatTime(startDate.addingTimeInterval(fast.targetDuration)))
                                .font(.subheadline.weight(.semibold))
                        }

                        Divider()
                            .frame(height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(fast.targetDuration / 3600))h")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        editableStartDate = startDate
                        editableTargetDuration = fast.targetDuration
                        showDialEditor = true
                    }
                }

                Spacer()

                // Action Button (Start / End)
                if fastManager.isFasting {
                    Button(
                        action: {
                            showStopConfirmation = true
                        },
                        label: {
                            Text("End Fast")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    )
                    .accessibilityIdentifier("end_fast_button")
                    .padding(.horizontal, 24)
                    .confirmationDialog(
                        "End Fast Early?",
                        isPresented: $showStopConfirmation,
                        titleVisibility: .visible,
                        actions: {
                            Button("End Fast", role: .destructive) {
                                fastManager.endFast(endDate: now)
                            }
                            Button("Cancel", role: .cancel) {}
                        },
                        message: {
                            Text("Are you sure you want to end your current fast?")
                        }
                    )
                } else {
                    Button(
                        action: {
                            fastManager.startFast(startDate: now)
                        },
                        label: {
                            Text("Start Fast")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    )
                    .accessibilityIdentifier("start_fast_button")
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 20)
            .sheet(isPresented: $showDialEditor) {
                DialEditorView(
                    startDate: $editableStartDate,
                    targetDuration: $editableTargetDuration,
                    onSave: { newStart, newDuration in
                        fastManager.updateActiveFast(startDate: newStart, targetDuration: newDuration)
                        showDialEditor = false
                    },
                    onCancel: {
                        showDialEditor = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func calculateProgress(at date: Date) -> Double {
        guard let fast = fastManager.activeFast, fast.targetDuration > 0 else {
            return 0.0
        }
        let startDate = fast.startDate ?? date
        let elapsed = date.timeIntervalSince(startDate)
        return max(0.0, elapsed / fast.targetDuration)
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
}
