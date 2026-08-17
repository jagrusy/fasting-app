import SwiftUI

public struct ProgressRingView: View {
    public let progress: Double // 0.0 to 1.0 (or > 1.0 when exceeded)
    public let isFasting: Bool
    public var ringWidth: CGFloat = 22

    public init(progress: Double, isFasting: Bool, ringWidth: CGFloat = 22) {
        self.progress = progress
        self.isFasting = isFasting
        self.ringWidth = ringWidth
    }

    private var clampedProgress: Double {
        min(max(progress, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color(.systemGray5),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )

            // Progress Arc
            Circle()
                .trim(from: 0.0, to: CGFloat(clampedProgress))
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            // Indicator Knob at tip when fasting
            if isFasting && clampedProgress > 0.02 {
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    let radius = (size - ringWidth) / 2
                    let angle = Angle.degrees(clampedProgress * 360 - 90)
                    let x = size / 2 + CGFloat(cos(angle.radians)) * radius
                    let y = size / 2 + CGFloat(sin(angle.radians)) * radius

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: ringWidth - 4, height: ringWidth - 4)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .position(x: x, y: y)
                }
            }
        }
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

#Preview {
    VStack(spacing: 40) {
        ProgressRingView(progress: 0.65, isFasting: true)
            .frame(width: 260, height: 260)

        ProgressRingView(progress: 1.0, isFasting: true)
            .frame(width: 260, height: 260)
    }
    .padding()
}
