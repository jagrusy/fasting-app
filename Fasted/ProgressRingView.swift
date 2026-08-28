import SwiftUI

public struct ProgressRingView: View {
    public let progress: Double
    public let isFasting: Bool
    public var ringWidth: CGFloat = 22
    /// Fires per drag frame with a small incremental fraction of a full revolution (not an absolute
    /// position), so the caller can accumulate elapsed time continuously across the 12-o'clock wrap
    /// point and past 100% without the knob's angle ever needing to represent more than one lap.
    public var onProgressDragged: ((Double) -> Void)?
    public var onProgressDragEnded: (() -> Void)?

    @State private var isDragging: Bool = false
    @State private var dragStartKnobPosition: CGPoint = .zero
    @State private var lastTouchAngle: Double = 0

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
                backgroundTrack(radius: radius)
                ambientSolarGlow(radius: radius)
                overGoalGlow(radius: radius)
                progressArc(radius: radius)
                if isFasting {
                    dragKnob(center: center, radius: radius)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func backgroundTrack(radius: CGFloat) -> some View {
        Circle()
            .stroke(
                Color(.systemGray5).opacity(0.6),
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    @ViewBuilder
    private func ambientSolarGlow(radius: CGFloat) -> some View {
        if isFasting {
            Circle()
                .trim(from: 0.0, to: CGFloat(clampedProgress))
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: ringWidth + 6, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .blur(radius: 8)
                .opacity(0.35)
        }
    }

    @ViewBuilder
    private func overGoalGlow(radius: CGFloat) -> some View {
        if isFasting && progress > 1.0 {
            Circle()
                .stroke(
                    SolsticeColors.emeraldGlow.opacity(0.4),
                    style: StrokeStyle(lineWidth: ringWidth + 10, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .blur(radius: 8)
        }
    }

    private func progressArc(radius: CGFloat) -> some View {
        Circle()
            .trim(from: 0.0, to: CGFloat(clampedProgress))
            .stroke(
                progressGradient,
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
            )
            .frame(width: radius * 2, height: radius * 2)
            .rotationEffect(.degrees(-90))
            .animation(isDragging ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: progress)
    }

    private func dragKnob(center: CGPoint, radius: CGFloat) -> some View {
        let angle = Angle.degrees(clampedProgress * 360.0 - 90.0)
        let knobX = center.x + CGFloat(cos(angle.radians)) * radius
        let knobY = center.y + CGFloat(sin(angle.radians)) * radius
        let knobSize = ringWidth + 6

        return Circle()
            .fill(Color(.systemBackground))
            .frame(width: knobSize, height: knobSize)
            .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
            .scaleEffect(isDragging ? 1.25 : 1.0)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .position(x: knobX, y: knobY)
            .accessibilityIdentifier("progress_knob")
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartKnobPosition = CGPoint(x: knobX, y: knobY)
                            lastTouchAngle = computeTouchAngle(point: dragStartKnobPosition, center: center)
                        }
                        let currentPoint = CGPoint(
                            x: dragStartKnobPosition.x + value.translation.width,
                            y: dragStartKnobPosition.y + value.translation.height
                        )
                        let touchAngle = computeTouchAngle(point: currentPoint, center: center)

                        var delta = touchAngle - lastTouchAngle
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }
                        lastTouchAngle = touchAngle

                        onProgressDragged?(delta / 360.0)
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartKnobPosition = .zero
                        onProgressDragEnded?()
                    }
            )
    }

    private func computeTouchAngle(point: CGPoint, center: CGPoint) -> Double {
        let deltaX = Double(point.x - center.x)
        let deltaY = Double(point.y - center.y)
        let radians = atan2(deltaY, deltaX)
        var degrees = radians * 180.0 / .pi
        degrees += 90 // 0 at top
        if degrees < 0 { degrees += 360 }
        return degrees
    }

    private var progressGradient: LinearGradient {
        if isFasting {
            if progress >= 1.0 {
                return SolsticeColors.goalMetGradient
            } else {
                return SolsticeColors.solarGradient
            }
        } else {
            return SolsticeColors.idleGradient
        }
    }
}
