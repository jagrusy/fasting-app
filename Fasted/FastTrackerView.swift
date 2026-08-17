import SwiftUI

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
                headerView
                progressSection(now: now)
                    .padding(.vertical, 8)

                if let fast = fastManager.activeFast {
                    startCardButton(fast: fast, now: now)
                }

                Spacer()

                actionButton(now: now)
            }
            .padding(.bottom, 20)
        }
    }

    private var headerView: some View {
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
    }

    private func progressSection(now: Date) -> some View {
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

            Button {
                if fastManager.isFasting {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        centerDisplayMode = centerDisplayMode.next
                    }
                }
            } label: {
                FastMetricsCenterView(
                    fast: fastManager.activeFast,
                    currentProtocol: fastManager.currentProtocol,
                    progress: progress,
                    centerDisplayMode: centerDisplayMode,
                    now: now
                )
            }
            .buttonStyle(.plain)
            .disabled(!fastManager.isFasting)
            .accessibilityIdentifier("progress_ring_button")
        }
    }

    private func startCardButton(fast: Fast, now: Date) -> some View {
        let startDate = fast.startDate ?? now
        return Button {
            tempStartDate = startDate
            showStartTimePicker = true
        } label: {
            startCardContent(startDate: startDate, targetDuration: fast.targetDuration)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fast_details_button")
        .sheet(isPresented: $showStartTimePicker) {
            startPickerSheet(now: now)
        }
    }

    private func startCardContent(startDate: Date, targetDuration: TimeInterval) -> some View {
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

            Divider().frame(height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Goal Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTime(startDate.addingTimeInterval(targetDuration)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func startPickerSheet(now: Date) -> some View {
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

    private func actionButton(now: Date) -> some View {
        Group {
            if fastManager.isFasting {
                endFastButton(now: now)
            } else {
                startFastButton(now: now)
            }
        }
    }

    private func endFastButton(now: Date) -> some View {
        Button(
            action: { showStopConfirmation = true },
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
                Button("End Fast", role: .destructive) { fastManager.endFast(endDate: now) }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("Are you sure you want to end your current fast?")
            }
        )
    }

    private func startFastButton(now: Date) -> some View {
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

    private func handleStartKnobDragged(touchAngle: Double, now: Date) {
        guard let fast = fastManager.activeFast else { return }
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
