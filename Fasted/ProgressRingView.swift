import SwiftUI

public struct ProgressRingView: View {
    public let progress: Double // 0.0 to 1.0 (or > 1.0 when exceeded)
    public let isFasting: Bool
    public var ringWidth: CGFloat = 22
    public var onStartKnobDragged: ((Double) -> Void)?
    public var onStartKnobDragEnded: (() -> Void)?

    @State private var isDraggingKnob: Bool = false

    public init(
        progress: Double,
        isFasting: Bool,
        ringWidth: CGFloat = 22,
        onStartKnobDragged: ((Double) -> Void)? = nil,
        onStartKnobDragEnded: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.isFasting = isFasting
        self.ringWidth = ringWidth
        self.onStartKnobDragged = onStartKnobDragged
        self.onStartKnobDragEnded = onStartKnobDragEnded
    }

    private var clampedProgress: Double {
        min(max(progress, 0.0), 1.0)
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = (size - ringWidth) / 2
            let center = CGPoint(x: size / 2, y: size / 2)

            ZStack {
                // Background track
                Circle()
                    .stroke(
                        Color(.systemGray5),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )

                // Over-goal glow ring (when progress > 100%)
                if isFasting && progress > 1.0 {
                    Circle()
                        .stroke(
                            Color.green.opacity(0.3),
                            style: StrokeStyle(lineWidth: ringWidth + 8, lineCap: .round)
                        )
                        .blur(radius: 6)
                }

                // Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(clampedProgress))
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(isDraggingKnob ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: progress)

                // End Tip indicator when fasting
                if isFasting && clampedProgress > 0.03 {
                    let endAngle = Angle.degrees(clampedProgress * 360 - 90)
                    let endX = center.x + CGFloat(cos(endAngle.radians)) * radius
                    let endY = center.y + CGFloat(sin(endAngle.radians)) * radius

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: ringWidth - 6, height: ringWidth - 6)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .position(x: endX, y: endY)
                }

                // Interactive Start Knob (at top / start of fast arc)
                if isFasting && onStartKnobDragged != nil {
                    let startKnobPos = CGPoint(x: center.x, y: center.y - radius)

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: ringWidth + 10, height: ringWidth + 10)
                        .overlay(
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.orange)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                        .scaleEffect(isDraggingKnob ? 1.25 : 1.0)
                        .position(startKnobPos)
                        .accessibilityIdentifier("ring_start_knob")
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingKnob = true
                                    let touchAngle = computeTouchAngle(point: value.location, center: center)
                                    onStartKnobDragged?(touchAngle)
                                }
                                .onEnded { _ in
                                    isDraggingKnob = false
                                    onStartKnobDragEnded?()
                                }
                        )
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func computeTouchAngle(point: CGPoint, center: CGPoint) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let radians = atan2(dy, dx)
        var degrees = radians * 180.0 / .pi
        degrees += 90 // 0 at top
        if degrees < 0 { degrees += 360 }
        return degrees
    }

    private var progressGradient: LinearGradient {
        if isFasting {
            if progress >= 1.0 {
                return LinearGradient(
                    colors: [Color.green, Color.teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color.orange, Color.red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            return LinearGradient(
                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
