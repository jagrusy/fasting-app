import SwiftUI

public struct DialEditorView: View {
    @Binding public var startDate: Date
    @Binding public var targetDuration: TimeInterval
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
        case start
        case end
        case arc
    }

    public init(
        startDate: Binding<Date>,
        targetDuration: Binding<TimeInterval>,
        onSave: @escaping (Date, TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._startDate = startDate
        self._targetDuration = targetDuration
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundStyle(.orange)
                            Text("FAST START")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Text(formatTime(startDate))
                            .font(.title3.weight(.bold))
                            .accessibilityIdentifier("dial_start_time_label")
                        Text(formatRelativeDay(for: startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered.circle.fill")
                                .foregroundStyle(.green)
                            Text("FAST END")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Text(formatTime(calculatedEndDate))
                            .font(.title3.weight(.bold))
                            .accessibilityIdentifier("dial_end_time_label")
                        Text(formatRelativeDay(for: calculatedEndDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Interactive 24-hour Dial
                ZStack {
                    // Base 24h clock face
                    DialFaceView(radius: dialRadius, strokeWidth: strokeWidth)

                    // Fasting arc (draggable in the middle)
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

                    // Start Handle (Knob)
                    let startPos = DialMath.pointOnCircle(
                        center: CGPoint(x: dialRadius, y: dialRadius),
                        radius: dialRadius,
                        angleDegrees: startAngle
                    )
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.orange)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                        .position(startPos)
                        .accessibilityIdentifier("dial_start_handle")

                    // End Handle (Knob)
                    let endPos = DialMath.pointOnCircle(
                        center: CGPoint(x: dialRadius, y: dialRadius),
                        radius: dialRadius,
                        angleDegrees: endAngle
                    )
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .overlay(
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.green)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                        .position(endPos)
                        .accessibilityIdentifier("dial_end_handle")
                }
                .frame(width: dialRadius * 2 + 40, height: dialRadius * 2 + 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged(handleDragChanged)
                        .onEnded(handleDragEnded)
                )
                .padding(.vertical, 10)

                // Duration summary under dial
                VStack(spacing: 4) {
                    Text(formatDuration(targetDuration))
                        .font(.title2.weight(.bold))
                        .accessibilityIdentifier("dial_duration_label")

                    Text(targetDuration >= 57600 ? "Meets popular 16:8 goal." : "Custom fasting window.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationTitle("Edit Fast Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .accessibilityIdentifier("dial_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(startDate, targetDuration)
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("dial_save_button")
                }
            }
            .onAppear(perform: setupInitialAngles)
        }
    }

    private func setupInitialAngles() {
        startAngle = DialMath.angle(for: startDate)
        let computedEnd = startDate.addingTimeInterval(targetDuration)
        endAngle = DialMath.angle(for: computedEnd)
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        let center = CGPoint(x: dialRadius + 20, y: dialRadius + 20)
        let currentTouchAngle = DialMath.touchAngle(point: value.location, center: center)

        if activeDragHandle == nil {
            // Determine which handle was touched
            let startPoint = DialMath.pointOnCircle(center: center, radius: dialRadius, angleDegrees: startAngle)
            let endPoint = DialMath.pointOnCircle(center: center, radius: dialRadius, angleDegrees: endAngle)

            let distToStart = hypot(value.startLocation.x - startPoint.x, value.startLocation.y - startPoint.y)
            let distToEnd = hypot(value.startLocation.x - endPoint.x, value.startLocation.y - endPoint.y)

            let touchRadius = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
            let isNearRing = abs(touchRadius - dialRadius) <= (strokeWidth / 2 + 15)

            if distToStart < knobRadius + 16 {
                activeDragHandle = .start
            } else if distToEnd < knobRadius + 16 {
                activeDragHandle = .end
            } else if isNearRing && DialMath.isAngle(currentTouchAngle, between: startAngle, and: endAngle) {
                activeDragHandle = .arc
                initialStartAngle = startAngle
                initialEndAngle = endAngle
                lastDragAngle = currentTouchAngle
            } else {
                return
            }
        }

        switch activeDragHandle {
        case .start:
            let snappedDate = DialMath.date(from: currentTouchAngle, baseDate: startDate, snapToMinutes: 5)
            let newAngle = DialMath.angle(for: snappedDate)
            startAngle = newAngle
            startDate = snappedDate
            targetDuration = DialMath.computeDuration(startAngle: startAngle, endAngle: endAngle)

        case .end:
            let rawEndDate = DialMath.date(from: currentTouchAngle, baseDate: startDate, snapToMinutes: 5)
            let newAngle = DialMath.angle(for: rawEndDate)
            endAngle = newAngle
            targetDuration = DialMath.computeDuration(startAngle: startAngle, endAngle: endAngle)

        case .arc:
            var delta = currentTouchAngle - lastDragAngle
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }

            startAngle = (startAngle + delta).truncatingRemainder(dividingBy: 360)
            if startAngle < 0 { startAngle += 360 }

            endAngle = (endAngle + delta).truncatingRemainder(dividingBy: 360)
            if endAngle < 0 { endAngle += 360 }

            startDate = DialMath.date(from: startAngle, baseDate: startDate, snapToMinutes: 5)
            lastDragAngle = currentTouchAngle

        case .none:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        activeDragHandle = nil
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatRelativeDay(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) hr"
        } else {
            return "\(hours) hr \(minutes) min"
        }
    }
}
