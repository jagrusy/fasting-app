import SwiftUI

public struct ProgressRingView: View {
    public let progress: Double // 0.0 to 1.0 (or > 1.0 when exceeded)
    public let isFasting: Bool
    public var ringWidth: CGFloat = 22
    public var onProgressDragged: ((Double) -> Void)?
    public var onProgressDragEnded: (() -> Void)?

    @State private var isDragging: Bool = false

    public init(
        progress: Double,
        isFasting: Bool,
        ringWidth: CGFloat = 22,
        onProgressDragged: ((Double) -> Void)? = nil,
        onProgressDragEnded: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.isFasting = isFasting
        self.ringWidth = ringWidth
        self.onProgressDragged = onProgressDragged
        self.onProgressDragEnded = onProgressDragEnded
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
                // Background track ring
                Circle()
                    .stroke(
                        Color(.systemGray5),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )

                // Over-goal glow ring (when progress > 100%)
                if isFasting && progress > 1.0 {
                    Circle()
                        .stroke(
                            Color.green.opacity(0.35),
                            style: StrokeStyle(lineWidth: ringWidth + 8, lineCap: .round)
                        )
                        .blur(radius: 6)
                }

                // Active Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(clampedProgress))
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(isDragging ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: progress)

                // Single Draggable Knob at tip of progress arc
                if isFasting {
                    let angle = Angle.degrees(clampedProgress * 360.0 - 90.0)
                    let knobX = center.x + CGFloat(cos(angle.radians)) * radius
                    let knobY = center.y + CGFloat(sin(angle.radians)) * radius

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: ringWidth + 6, height: ringWidth + 6)
                        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                        .scaleEffect(isDragging ? 1.25 : 1.0)
                        .position(x: knobX, y: knobY)
                        .accessibilityIdentifier("progress_knob")
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let touchAngle = computeTouchAngle(point: value.location, center: center)
                                    let newProgress = touchAngle / 360.0
                                    onProgressDragged?(newProgress)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    onProgressDragEnded?()
                                }
                        )
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func computeTouchAngle(point: CGPoint, center: CGPoint) -> Double {
        let deltaX = Double(point.x - center.x)
        let deltaY = Double(point.y - center.y)
        let radians = atan2(deltaY, deltaX)
        var degrees = radians * 180.0 / .pi
        degrees += 90 // 0 at top (12 o'clock)
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
