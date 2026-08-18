import SwiftUI

public struct FastTrackerView: View {
    @ObservedObject var fastManager: FastManager
    @State private var showStopConfirmation: Bool = false
    @State private var showTimePickerSheet: Bool = false
    @State private var showStagesSheet: Bool = false
    @State private var centerDisplayMode: CenterDisplayMode = .elapsed
    @State private var tempTime: Date = Date()

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0)) { context in
            trackerContent(now: context.date)
        }
        .sheet(isPresented: $showStagesSheet) {
            let elapsed = fastManager.elapsedTime(at: Date())
            MetabolicStagesSheetView(
                currentStage: fastManager.isFasting ? MetabolicStage.stage(for: elapsed) : nil,
                elapsedSeconds: elapsed
            )
        }
    }

    private func trackerContent(now: Date) -> some View {
        let progress = calculateProgress(at: now)
        return VStack(spacing: 20) {
            headerView(progress: progress)
            progressSection(now: now, progress: progress)

            if fastManager.isFasting {
                let elapsed = fastManager.elapsedTime(at: now)
                let currentStage = MetabolicStage.stage(for: elapsed)
                MetabolicStageBadgeView(stage: currentStage) {
                    showStagesSheet = true
                }
                .padding(.top, -6)
            }

            if let fast = fastManager.activeFast {
                FastStartedCardView(
                    fast: fast,
                    now: now,
                    onSelectDayOffset: { offset in
                        updateStartDate(dayOffset: offset, from: fast.startDate ?? now)
                    },
                    onSelectTime: {
                        tempTime = fast.startDate ?? now
                        showTimePickerSheet = true
                    }
                )
                .sheet(isPresented: $showTimePickerSheet) {
                    timePickerSheet(startDate: fast.startDate ?? now, now: now)
                }
            }

            Spacer()

            actionButton(now: now, progress: progress)
        }
        .padding(.bottom, 20)
    }

    private func headerView(progress: Double) -> some View {
        VStack(spacing: 6) {
            Text(fastManager.isFasting ? "Current Fast" : "Ready to Fast")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let statusTitle: String = {
                if !fastManager.isFasting {
                    return "\(fastManager.currentProtocol.name) (\(fastManager.currentProtocol.ratioString))"
                }
                return progress >= 1.0 ? "Goal Reached! 🎉" : "Fasting in Progress"
            }()

            Text(statusTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(progress >= 1.0 && fastManager.isFasting ? .green : Color.primary)
                .accessibilityIdentifier("fast_status_header")
        }
        .padding(.top, 16)
    }

    private func progressSection(now: Date, progress: Double) -> some View {
        ZStack {
            ProgressRingView(
                progress: progress,
                isFasting: fastManager.isFasting,
                ringWidth: 24,
                onProgressDragged: { newProgress in
                    handleProgressDragged(newProgress: newProgress, now: now)
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

    private func timePickerSheet(startDate: Date, now: Date) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Start Time",
                    selection: $tempTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()

                Spacer()
            }
            .navigationTitle("Adjust Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTimePickerSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyTimeChange(newTime: tempTime, originalDate: startDate, now: now)
                        showTimePickerSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    private func applyTimeChange(newTime: Date, originalDate: Date, now: Date) {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: originalDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = 0

        if let combinedDate = calendar.date(from: dateComponents) {
            let finalDate = min(combinedDate, now)
            fastManager.updateActiveFast(startDate: finalDate)
        }
    }

    private func updateStartDate(dayOffset: Int, from currentDate: Date) {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: currentDate)
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) ?? Date()

        var combinedComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        if let newStartDate = calendar.date(from: combinedComponents) {
            fastManager.updateActiveFast(startDate: min(newStartDate, Date()))
        }
    }

    private func actionButton(now: Date, progress: Double) -> some View {
        Group {
            if fastManager.isFasting {
                endFastButton(now: now, goalReached: progress >= 1.0)
            } else {
                startFastButton(now: now)
            }
        }
    }

    private func endFastButton(now: Date, goalReached: Bool) -> some View {
        let buttonTitle = goalReached ? "Complete Fast" : "End Fast"
        let dialogTitle = goalReached ? "Complete Fast" : "End Fast Early?"
        let dialogMessage = goalReached
            ? "Great work! You've reached your fasting goal."
            : "Are you sure you want to end your current fast?"

        return Button {
            if goalReached {
                fastManager.endFast(endDate: now)
            } else {
                showStopConfirmation = true
            }
        } label: {
            Text(buttonTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(goalReached ? Color.green : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityIdentifier("end_fast_button")
        .padding(.horizontal, 24)
        .confirmationDialog(
            dialogTitle,
            isPresented: $showStopConfirmation,
            titleVisibility: .visible,
            actions: {
                Button("End Fast", role: .destructive) { fastManager.endFast(endDate: now) }
                Button("Cancel", role: .cancel) {}
            },
            message: { Text(dialogMessage) }
        )
    }

    private func startFastButton(now: Date) -> some View {
        Button {
            NotificationManager.shared.requestAuthorization()
            fastManager.startFast(startDate: now)
        } label: {
            Text("Start Fast")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityIdentifier("start_fast_button")
        .padding(.horizontal, 24)
    }

    private func handleProgressDragged(newProgress: Double, now: Date) {
        guard let fast = fastManager.activeFast else { return }
        let clamped = min(max(newProgress, 0.0), 1.0)
        let elapsedSeconds = clamped * fast.targetDuration
        let adjustedStart = now.addingTimeInterval(-elapsedSeconds)

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
}
