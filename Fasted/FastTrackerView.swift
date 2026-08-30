import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct FastTrackerView: View {
    @ObservedObject var fastManager: FastManager
    @State private var showTimePickerSheet: Bool = false
    @State private var showStagesSheet: Bool = false
    @State private var centerDisplayMode: CenterDisplayMode = .elapsed
    @State private var tempTime: Date = Date()
    /// Snapped value, used for everything the user sees.
    @State private var draggingElapsed: TimeInterval?
    /// Unsnapped accumulator. Kept separately because snapping the running total each frame
    /// discards any movement smaller than half a step, so a slow drag would accumulate nothing
    /// and the ring would feel stuck until you moved fast enough to clear the threshold.
    @State private var dragRawElapsed: TimeInterval?
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String?

    public init(fastManager: FastManager) {
        self.fastManager = fastManager
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0)) { context in
            trackerContent(now: context.date)
        }
        .sheet(isPresented: $showStagesSheet) {
            let now = Date()
            let elapsed: TimeInterval = fastManager.activeFast.map {
                now.timeIntervalSince($0.startDate ?? now)
            } ?? 0
            MetabolicStagesSheetView(
                currentStage: fastManager.isFasting ? MetabolicStage.stage(for: elapsed) : nil,
                elapsedSeconds: elapsed
            )
        }
        .alert("Can't Move Fast There", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "That time overlaps with another fast.")
        }
    }

    private func trackerContent(now: Date) -> some View {
        let progress = displayedProgress(now: now)
        let previewStart = previewStartDate(now: now)
        return VStack(spacing: 20) {
            headerView(progress: progress)
            progressSection(now: now, progress: progress, previewStart: previewStart)

            if fastManager.isFasting {
                let elapsed: TimeInterval = fastManager.activeFast.map {
                    now.timeIntervalSince(previewStart ?? $0.startDate ?? now)
                } ?? 0
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
                    previewStartDate: previewStart,
                    onSelectDayOffset: { offset in
                        updateStartDate(dayOffset: offset, from: fast.startDate ?? now)
                    },
                    onSelectTime: {
                        tempTime = fast.startDate ?? now
                        showTimePickerSheet = true
                    }
                )
                .sheet(isPresented: $showTimePickerSheet) {
                    FastTimePickerSheetView(
                        tempTime: $tempTime,
                        onCancel: { showTimePickerSheet = false },
                        onSave: { newTime in
                            applyTimeChange(newTime: newTime, originalDate: fast.startDate ?? now, now: now)
                            showTimePickerSheet = false
                        }
                    )
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

    private func progressSection(now: Date, progress: Double, previewStart: Date?) -> some View {
        ZStack {
            ProgressRingView(
                progress: progress,
                isFasting: fastManager.isFasting,
                ringWidth: 24,
                onProgressDragged: { deltaProgress in
                    handleProgressDragDelta(deltaProgress: deltaProgress, now: now)
                },
                onProgressDragEnded: {
                    commitProgressDrag(now: now)
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
                    now: now,
                    previewStartDate: previewStart
                )
            }
            .buttonStyle(.plain)
            .disabled(!fastManager.isFasting)
            .accessibilityIdentifier("progress_ring_button")
        }
    }

    private func applyTimeChange(newTime: Date, originalDate: Date, now: Date) {
        guard let fast = fastManager.activeFast else { return }
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: originalDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = 0

        if let combinedDate = calendar.date(from: dateComponents) {
            let finalDate = min(combinedDate, now)
            applyValidatedStartDate(finalDate, excludingFastId: fast.id)
        }
    }

    private func updateStartDate(dayOffset: Int, from currentDate: Date) {
        guard let fast = fastManager.activeFast else { return }
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: currentDate)
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) ?? Date()

        var combinedComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        if let newStartDate = calendar.date(from: combinedComponents) {
            applyValidatedStartDate(min(newStartDate, Date()), excludingFastId: fast.id)
        }
    }

    private func applyValidatedStartDate(_ startDate: Date, excludingFastId: UUID?) {
        let validation = fastManager.validateInterval(startDate: startDate, excludingFastId: excludingFastId)
        guard validation.isValid else {
            validationMessage = validation.message
            showValidationAlert = true
            return
        }
        fastManager.updateActiveFast(startDate: startDate)
    }

    private func actionButton(now: Date, progress: Double) -> some View {
        Group {
            if fastManager.isFasting {
                EndFastButtonView(
                    goalReached: progress >= 1.0,
                    onComplete: { fastManager.endFast(endDate: now) },
                    onSave: { fastManager.endFast(endDate: now) },
                    onDiscard: { fastManager.discardActiveFast() }
                )
            } else {
                startFastButton(now: now)
            }
        }
    }

    private func startFastButton(now: Date) -> some View {
        Button {
            let tapDate = Date()
            fastManager.startFast(startDate: tapDate)
            NotificationManager.shared.requestAuthorization { granted in
                if granted {
                    fastManager.syncNotifications()
                }
            }
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

    /// `deltaProgress` is a small incremental fraction of a full revolution, not an absolute position —
    /// this keeps the drag continuous across the 12-o'clock wrap point and lets a fast that's already
    /// past its goal (>100%) be nudged further without snapping back down to wherever the touch angle
    /// happens to land.
    private func handleProgressDragDelta(deltaProgress: Double, now: Date) {
        guard let fast = fastManager.activeFast, fast.targetDuration > 0 else { return }
        let baseline = dragRawElapsed ?? now.timeIntervalSince(fast.startDate ?? now)
        let rawElapsed = max(0, baseline + deltaProgress * fast.targetDuration)
        dragRawElapsed = rawElapsed

        let snappedElapsed = DialMath.snapInterval(rawElapsed, toMinutes: 5)
        if let previous = draggingElapsed, previous != snappedElapsed {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
        draggingElapsed = snappedElapsed
    }

    private func commitProgressDrag(now: Date) {
        defer {
            draggingElapsed = nil
            dragRawElapsed = nil
        }
        guard let fast = fastManager.activeFast, let elapsed = draggingElapsed else { return }
        let adjustedStart = now.addingTimeInterval(-elapsed)
        let validation = fastManager.validateInterval(startDate: adjustedStart, excludingFastId: fast.id)
        guard validation.isValid else {
            validationMessage = validation.message
            showValidationAlert = true
            return
        }
        fastManager.updateActiveFast(startDate: adjustedStart, targetDuration: fast.targetDuration)
    }

    private func displayedProgress(now: Date) -> Double {
        if let dragging = draggingElapsed, let fast = fastManager.activeFast, fast.targetDuration > 0 {
            return max(0.0, dragging / fast.targetDuration)
        }
        return calculateProgress(at: now)
    }

    /// While a drag is in flight nothing is written to Core Data until release, so `fast.startDate`
    /// is stale. Every readout (elapsed clock, START time, GOAL TARGET) needs this instead, or the
    /// ring appears to move while all the numbers sit frozen until you lift your finger.
    private func previewStartDate(now: Date) -> Date? {
        guard let dragging = draggingElapsed else { return nil }
        return now.addingTimeInterval(-dragging)
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
