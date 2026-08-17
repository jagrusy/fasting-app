import SwiftUI

public enum CenterDisplayMode: String, CaseIterable {
    case elapsed = "ELAPSED"
    case remaining = "REMAINING"
    case percentage = "COMPLETED"

    public var next: CenterDisplayMode {
        switch self {
        case .elapsed: return .remaining
        case .remaining: return .percentage
        case .percentage: return .elapsed
        }
    }
}

public struct FastTrackerView: View {
    @ObservedObject var fastManager: FastManager
    @State private var showStopConfirmation: Bool = false
    @State private var showStartTimePicker: Bool = false
    @State private var centerDisplayMode: CenterDisplayMode = .elapsed
    @State private var tempStartDate: Date = Date()

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

                // Main Circular Progress Display
                ZStack {
                    let progress = calculateProgress(at: now)

                    ProgressRingView(
                        progress: progress,
                        isFasting: fastManager.isFasting,
                        ringWidth: 24,
                        onStartKnobDragged: { touchAngle in
                            handleStartKnobDragged(touchAngle: touchAngle, now: now)
                        }
                    )
                    .frame(width: 280, height: 280)

                    // Inner Tap-to-Cycle Display
                    Button {
                        if fastManager.isFasting {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                centerDisplayMode = centerDisplayMode.next
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            if let fast = fastManager.activeFast {
                                let startDate = fast.startDate ?? now
                                let elapsed = max(0, now.timeIntervalSince(startDate))
                                let remaining = fast.targetDuration - elapsed

                                Text(centerDisplayMode.rawValue)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)

                                switch centerDisplayMode {
                                case .elapsed:
                                    Text(formatDuration(elapsed))
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.primary)
                                        .accessibilityIdentifier("elapsed_time_text")

                                    Text("\(Int(progress * 100))% · \(fastManager.currentProtocol.ratioString)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(progress >= 1.0 ? .green : .secondary)
                                        .accessibilityIdentifier("progress_percentage_text")

                                case .remaining:
                                    let remainingText = remaining > 0 ? formatDuration(remaining) : "Goal Met!"
                                    Text(remainingText)
                                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                                        .foregroundStyle(remaining > 0 ? Color.primary : Color.green)
                                        .accessibilityIdentifier("remaining_time_text")

                                    Text("Goal: \(formatTime(startDate.addingTimeInterval(fast.targetDuration)))")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)

                                case .percentage:
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                        .foregroundStyle(progress >= 1.0 ? Color.green : Color.primary)
                                        .accessibilityIdentifier("percentage_display_text")

                                    Text("\(formatDuration(elapsed)) of \(Int(fast.targetDuration / 3600))h")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }

                                Text("Tap to switch metric")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                            } else {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.orange)
                                    .padding(.bottom, 4)

                                Text(fastManager.currentProtocol.ratioString)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.primary)

                                Text(fastManager.currentProtocol.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!fastManager.isFasting)
                    .accessibilityIdentifier("progress_ring_button")
                }
                .padding(.vertical, 8)

                // Inline Start Card with manual tap to edit
                if let fast = fastManager.activeFast {
                    let startDate = fast.startDate ?? now
                    Button {
                        tempStartDate = startDate
                        showStartTimePicker = true
                    } label: {
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Started")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Text(formatTime(startDate))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                            }

                            Divider()
                                .frame(height: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Goal Target")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatTime(startDate.addingTimeInterval(fast.targetDuration)))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fast_details_button")
                    .sheet(isPresented: $showStartTimePicker) {
                        NavigationStack {
                            VStack(spacing: 24) {
                                DatePicker(
                                    "Fast Start Time",
                                    selection: $tempStartDate,
                                    in: ...now,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.graphical)
                                .padding()

                                Spacer()
                            }
                            .navigationTitle("Adjust Start Time")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { showStartTimePicker = false }
                                }
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Save") {
                                        fastManager.updateActiveFast(startDate: tempStartDate)
                                        showStartTimePicker = false
                                    }
                                    .fontWeight(.semibold)
                                }
                            }
                        }
                        .presentationDetents([.medium, .large])
                    }
                }

                Spacer()

                // Primary Start / End Button
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
                            NotificationManager.shared.requestAuthorization()
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
        }
    }

    private func handleStartKnobDragged(touchAngle: Double, now: Date) {
        guard let fast = fastManager.activeFast else { return }
        // touchAngle: 0 at top, 90 at right, 270 at left
        // Dragging counter-clockwise (towards 270) moves start time earlier
        // Fraction of circle from top counter-clockwise: (360 - touchAngle) / 360
        let fraction = touchAngle > 180 ? (360.0 - touchAngle) / 360.0 : 0.0
        let maxAdjustmentHours: Double = 12.0
        let hoursBack = fraction * maxAdjustmentHours
        let adjustedStart = now.addingTimeInterval(-hoursBack * 3600.0)

        fastManager.updateActiveFast(startDate: adjustedStart, targetDuration: fast.targetDuration)
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
