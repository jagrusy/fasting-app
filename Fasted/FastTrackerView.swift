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
    @State private var quickSelectMode: QuickSelectMode?

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
        .sheet(item: $quickSelectMode) { mode in
            ProtocolPickerView(
                fastManager: fastManager,
                presentation: mode.presentation(
                    fastManager: fastManager,
                    onStartFast: { proto in
                        beginFast(targetDuration: proto.fastingSeconds, protocolType: proto.ratioString)
                    }
                )
            )
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
            } else if let eatingEnd = fastManager.latestSnapshot.eatingWindowEnd(), eatingEnd > now {
                eatingWindowBadge(until: eatingEnd)
                    .padding(.top, -6)
            }

            if let fast = fastManager.activeFast {
                FastStartedCardView(
                    fast: fast, now: now, previewStartDate: previewStart,
                    effectiveTargetDuration: activeTargetDuration,
                    onSelectDayOffset: { updateStartDate(dayOffset: $0, from: fast.startDate ?? now) },
                    onSelectTime: {
                        tempTime = fast.startDate ?? now
                        showTimePickerSheet = true
                    },
                    onExtendOneHour: { fastManager.snoozeFast(by: 3600) },
                    onChangeGoal: { quickSelectMode = .retargetGoal }
                )
                .sheet(isPresented: $showTimePickerSheet) {
                    FastTimePickerSheetView(
                        tempTime: $tempTime,
                        onCancel: { showTimePickerSheet = false },
                        onSave: { newTime in
                            applyTimeChange(newTime: newTime, now: now)
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

    private func eatingWindowBadge(until eatingEnd: Date) -> some View {
        Label(
            "Eating window until \(FastDurationFormatter.formatTime(eatingEnd))",
            systemImage: "fork.knife"
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(SolsticeColors.tealGlow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SolsticeColors.tealGlow.opacity(0.12), in: Capsule())
        .accessibilityIdentifier("eating_window_badge")
    }

    private func headerView(progress: Double) -> some View {
        VStack(spacing: 6) {
            if fastManager.isFasting {
                let activeLabel = FastingProtocol.label(
                    forTargetDuration: activeTargetDuration,
                    protocolType: fastManager.activeFast?.protocolType
                )
                Text("CURRENT FAST · \(activeLabel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                let title = progress >= 1.0 ? "Goal Reached! 🎉" : "Fasting in Progress"
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(progress >= 1.0 ? .green : Color.primary)
                    .accessibilityIdentifier("fast_status_header")
            } else {
                Text("Ready to Fast")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Button {
                    quickSelectMode = .choosePlan
                } label: {
                    HStack(spacing: 6) {
                        Text(fastManager.currentProtocol.displayTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.primary)
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fast_status_header")
            }
        }
        .padding(.top, 16)
    }

    private var activeTargetDuration: TimeInterval {
        fastManager.activeFast.map { fastManager.effectiveTargetDuration(for: $0) } ?? 0
    }

    private func progressSection(now: Date, progress: Double, previewStart: Date?) -> some View {
        ZStack {
            ProgressRingView(
                progress: progress,
                isFasting: fastManager.isFasting,
                ringWidth: 24,
                targetDuration: activeTargetDuration,
                onProgressDragged: { handleProgressDragDelta(deltaProgress: $0, now: now) },
                onProgressDragEnded: { commitProgressDrag(now: now) }
            )
            .frame(width: 280, height: 280)

            Button {
                if fastManager.isFasting {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        centerDisplayMode = centerDisplayMode.next
                    }
                } else {
                    quickSelectMode = .choosePlan
                }
            } label: {
                FastMetricsCenterView(
                    fast: fastManager.activeFast, currentProtocol: fastManager.currentProtocol,
                    progress: progress, centerDisplayMode: centerDisplayMode, now: now,
                    previewStartDate: previewStart, effectiveTargetDuration: activeTargetDuration
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress_ring_button")
        }
    }

    private func applyTimeChange(newTime: Date, now: Date) {
        guard let fast = fastManager.activeFast else { return }
        let normalized = FastDurationFormatter.floorToMinute(newTime)
        let clamped = min(normalized, now)
        applyValidatedStartDate(clamped, excludingFastId: fast.id)
    }
}

// MARK: - Dragging, dates, and start controls

private extension FastTrackerView {
    func updateStartDate(dayOffset: Int, from currentDate: Date) {
        guard let fast = fastManager.activeFast else { return }
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: currentDate)
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) ?? Date()

        var combinedComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        if let newStartDate = calendar.date(from: combinedComponents) {
            applyValidatedStartDate(newStartDate, excludingFastId: fast.id)
        }
    }

    func applyValidatedStartDate(_ startDate: Date, excludingFastId: UUID?) {
        let validation = fastManager.validateInterval(startDate: startDate, excludingFastId: excludingFastId)
        guard validation.isValid else {
            validationMessage = validation.message
            showValidationAlert = true
            return
        }
        fastManager.updateActiveFast(startDate: startDate)
    }

    func actionButton(now: Date, progress: Double) -> some View {
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

    /// `deltaProgress` is a small incremental fraction of a full revolution, not an absolute position —
    /// this keeps the drag continuous across the 12-o'clock wrap point and lets a fast that's already
    /// past its goal (>100%) be nudged further without snapping back down to wherever the touch angle
    /// happens to land.
    func handleProgressDragDelta(deltaProgress: Double, now: Date) {
        let target = activeTargetDuration
        guard let fast = fastManager.activeFast, target > 0 else { return }
        let baseline = dragRawElapsed ?? now.timeIntervalSince(fast.startDate ?? now)
        let rawElapsed = max(0, baseline + deltaProgress * target)
        dragRawElapsed = rawElapsed

        let snappedElapsed = DialMath.snapInterval(rawElapsed, toMinutes: 5)
        if let previous = draggingElapsed, previous != snappedElapsed {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
        draggingElapsed = snappedElapsed
    }

    func commitProgressDrag(now: Date) {
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

    func displayedProgress(now: Date) -> Double {
        let target = activeTargetDuration
        if let dragging = draggingElapsed, target > 0 {
            return max(0.0, dragging / target)
        }
        return calculateProgress(at: now)
    }

    /// While a drag is in flight nothing is written to Core Data until release, so `fast.startDate`
    /// is stale. Every readout (elapsed clock, START time, GOAL TARGET) needs this instead, or the
    /// ring appears to move while all the numbers sit frozen until you lift your finger.
    func previewStartDate(now: Date) -> Date? {
        guard let dragging = draggingElapsed else { return nil }
        return now.addingTimeInterval(-dragging)
    }

    func calculateProgress(at date: Date) -> Double {
        let target = activeTargetDuration
        guard let fast = fastManager.activeFast, target > 0 else {
            return 0.0
        }
        let startDate = fast.startDate ?? date
        let elapsed = date.timeIntervalSince(startDate)
        return max(0.0, elapsed / target)
    }

    var startMenuSegmentWidth: CGFloat { 56 }

    /// Starts the default protocol, with a trailing quick-select button for choosing any plan.
    func startFastButton(now: Date) -> some View {
        HStack(spacing: 0) {
            Button {
                beginFast(targetDuration: nil, protocolType: nil)
            } label: {
                Text("Start Fast") // inset by divider + chevron so it centres under the ring
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, startMenuSegmentWidth + 1)
                    .frame(height: 56)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("start_fast_button")

            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 1, height: 28)

            Button {
                quickSelectMode = .startFast
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: startMenuSegmentWidth, height: 56)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("start_fast_menu")
            .accessibilityLabel("Choose fast type")
        }
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    func beginFast(targetDuration: TimeInterval?, protocolType: String?) {
        guard fastManager.startFast(
            startDate: Date(), targetDuration: targetDuration, protocolType: protocolType
        ) != nil else { return }
        NotificationManager.shared.requestAuthorization { granted in
            if granted {
                fastManager.syncNotifications()
            }
        }
    }
}
