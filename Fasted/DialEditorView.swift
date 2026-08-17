import SwiftUI

public enum FastEditMode: Equatable {
    /// Active in-progress fast: only the start time can be adjusted (target duration and end handle remain fixed)
    case inProgress
    /// Completed historical fast: both start and end times / duration and window shifting can be edited
    case completed
}

public struct DialEditorView: View {
    @Binding public var startDate: Date
    @Binding public var targetDuration: TimeInterval
    public let mode: FastEditMode
    public let onSave: (Date, TimeInterval) -> Void
    public let onCancel: () -> Void

    @State private var startAngle: Double = 0.0
    @State private var endAngle: Double = 0.0
    @State private var initialStartAngle: Double = 0.0
    @State private var initialEndAngle: Double = 0.0

    @State private var activeDragHandle: DragHandle?
    @State private var lastDragAngle: Double = 0.0

    private let dialRadius: CGFloat = 135
    private let strokeWidth: CGFloat = 34
    private let knobRadius: CGFloat = 18

    private enum DragHandle {
        case start, end, arc
    }

    public init(
        startDate: Binding<Date>,
        targetDuration: Binding<TimeInterval>,
        mode: FastEditMode = .inProgress,
        onSave: @escaping (Date, TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._startDate = startDate
        self._targetDuration = targetDuration
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var calculatedEndDate: Date {
        startDate.addingTimeInterval(targetDuration)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header with Bedtime / Wake Up style cards
                HStack(spacing: 20) {
                    DialHeaderCardView(
                        title: "FAST START",
                        systemImage: "fork.knife.circle.fill",
                        imageColor: .orange,
                        date: startDate,
                        identifier: "dial_start_time_label"
                    )

                    DialHeaderCardView(
                        title: mode == .inProgress ? "TARGET END" : "FAST END",
                        systemImage: "flag.checkered.circle.fill",
                        imageColor: .green,
                        date: calculatedEndDate,
                        identifier: "dial_end_time_label"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Interactive 24-hour Dial
                dialCanvas
                    .padding(.vertical, 10)

                // Duration summary under dial
                VStack(spacing: 4) {
                    Text(formatDuration(targetDuration))
                        .font(.title2.weight(.bold))
                        .accessibilityIdentifier("dial_duration_label")

                    Text(mode == .inProgress
                         ? "Drag start handle to adjust when your active fast started."
                         : (targetDuration >= 57600 ? "Meets popular 16:8 goal." : "Custom fasting window."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .navigationTitle(mode == .inProgress ? "Edit Start Time" : "Edit Fast Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("dial_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(startDate, targetDuration) }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("dial_save_button")
                }
            }
            .onAppear(perform: setupInitialAngles)
        }
    }

    private var dialCanvas: some View {
        ZStack {
            DialFaceView(radius: dialRadius, strokeWidth: strokeWidth)

            FastingArcShape(startAngle: startAngle, endAngle: endAngle)
                .stroke(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: dialRadius * 2, height: dialRadius * 2)

            handleView(
                angle: startAngle,
                icon: "fork.knife",
                color: .orange,
                identifier: "dial_start_handle",
                isLocked: false
            )

            handleView(
                angle: endAngle,
                icon: mode == .inProgress ? "lock.fill" : "flag.fill",
                color: mode == .inProgress ? .secondary : .green,
                identifier: "dial_end_handle",
                isLocked: mode == .inProgress
            )
        }
        .frame(width: dialRadius * 2 + 40, height: dialRadius * 2 + 40)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(handleDragChanged)
                .onEnded(handleDragEnded)
        )
    }

    private func handleView(
        angle: Double,
        icon: String,
        color: Color,
        identifier: String,
        isLocked: Bool
    ) -> some View {
        let pos = DialMath.pointOnCircle(
            center: CGPoint(x: dialRadius, y: dialRadius),
            radius: dialRadius,
            angleDegrees: angle
        )
        return Circle()
            .fill(isLocked ? Color(.secondarySystemBackground) : Color(.systemBackground))
            .frame(width: knobRadius * 2, height: knobRadius * 2)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: isLocked ? 11 : 13, weight: .bold))
                    .foregroundStyle(color)
            )
            .shadow(color: Color.black.opacity(isLocked ? 0.1 : 0.25), radius: 4, x: 0, y: 2)
            .position(pos)
            .accessibilityIdentifier(identifier)
    }

    private func setupInitialAngles() {
        startAngle = DialMath.angle(for: startDate)
        let computedEnd = startDate.addingTimeInterval(targetDuration)
        endAngle = DialMath.angle(for: computedEnd)
    }

    private func detectHandle(at touchPoint: CGPoint, touchAngle: Double, center: CGPoint) -> DragHandle? {
        let startPoint = DialMath.pointOnCircle(center: center, radius: dialRadius, angleDegrees: startAngle)
        let distToStart = hypot(touchPoint.x - startPoint.x, touchPoint.y - startPoint.y)

        if distToStart < knobRadius + 16 {
            return .start
        }

        // If fast is in progress, only start knob can be dragged
        if mode == .inProgress {
            return nil
        }

        let endPoint = DialMath.pointOnCircle(center: center, radius: dialRadius, angleDegrees: endAngle)
        let distToEnd = hypot(touchPoint.x - endPoint.x, touchPoint.y - endPoint.y)
        let touchRadius = hypot(touchPoint.x - center.x, touchPoint.y - center.y)
        let isNearRing = abs(touchRadius - dialRadius) <= (strokeWidth / 2 + 15)

        if distToEnd < knobRadius + 16 {
            return .end
        } else if isNearRing && DialMath.isAngle(touchAngle, between: startAngle, and: endAngle) {
            return .arc
        }
        return nil
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        let center = CGPoint(x: dialRadius + 20, y: dialRadius + 20)
        let touchAngle = DialMath.touchAngle(point: value.location, center: center)

        if activeDragHandle == nil {
            guard let handle = detectHandle(at: value.startLocation, touchAngle: touchAngle, center: center) else {
                return
            }
            activeDragHandle = handle
            if handle == .arc {
                initialStartAngle = startAngle
                initialEndAngle = endAngle
                lastDragAngle = touchAngle
            }
        }

        applyDragUpdate(touchAngle: touchAngle)
    }

    private func applyDragUpdate(touchAngle: Double) {
        switch activeDragHandle {
        case .start:
            let snappedDate = DialMath.date(from: touchAngle, baseDate: startDate, snapToMinutes: 5)
            startAngle = DialMath.angle(for: snappedDate)
            startDate = snappedDate
            if mode == .inProgress {
                // In-progress: duration stays preserved, end angle moves with start
                let computedEnd = startDate.addingTimeInterval(targetDuration)
                endAngle = DialMath.angle(for: computedEnd)
            } else {
                // Completed: adjust duration based on fixed end knob
                targetDuration = DialMath.computeDuration(startAngle: startAngle, endAngle: endAngle)
            }

        case .end:
            let rawEndDate = DialMath.date(from: touchAngle, baseDate: startDate, snapToMinutes: 5)
            endAngle = DialMath.angle(for: rawEndDate)
            targetDuration = DialMath.computeDuration(startAngle: startAngle, endAngle: endAngle)

        case .arc:
            var delta = touchAngle - lastDragAngle
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }

            startAngle = (startAngle + delta).truncatingRemainder(dividingBy: 360)
            if startAngle < 0 { startAngle += 360 }

            endAngle = (endAngle + delta).truncatingRemainder(dividingBy: 360)
            if endAngle < 0 { endAngle += 360 }

            startDate = DialMath.date(from: startAngle, baseDate: startDate, snapToMinutes: 5)
            lastDragAngle = touchAngle

        case .none:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        activeDragHandle = nil
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes) min"
        } else if minutes == 0 {
            return "\(hours) hrs"
        } else {
            return "\(hours) hrs \(minutes) min"
        }
    }
}
