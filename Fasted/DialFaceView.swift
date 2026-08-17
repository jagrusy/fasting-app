import SwiftUI

public struct DialFaceView: View {
    public let radius: CGFloat
    public let strokeWidth: CGFloat

    public init(radius: CGFloat, strokeWidth: CGFloat = 36) {
        self.radius = radius
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        ZStack {
            trackBackgroundRing
            hourTicksAndLabels
            sunMoonIndicators
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private var trackBackgroundRing: some View {
        Circle()
            .stroke(
                Color(.systemGray6),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    private var hourTicksAndLabels: some View {
        ForEach(0..<24, id: \.self) { hour in
            let angle = Double(hour) * 15.0 // 360 / 24 = 15°
            let isMajor = (hour % 6 == 0) // 12AM, 6AM, 12PM, 6PM
            let isMedium = (hour % 3 == 0)

            Rectangle()
                .fill(isMajor ? Color.primary : (isMedium ? Color.secondary : Color(.systemGray4)))
                .frame(
                    width: isMajor ? 2.5 : (isMedium ? 1.5 : 1.0),
                    height: isMajor ? 10 : (isMedium ? 6 : 4)
                )
                .offset(y: -(radius - strokeWidth / 2))
                .rotationEffect(.degrees(angle))

            if isMajor {
                let pos = labelPosition(for: angle, distance: radius - strokeWidth - 18)
                Text(label(for: hour))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .position(pos)
            } else if isMedium {
                let pos = labelPosition(for: angle, distance: radius - strokeWidth - 18)
                Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .position(pos)
            }
        }
    }

    private var sunMoonIndicators: some View {
        VStack(spacing: 36) {
            Image(systemName: "moon.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.indigo)

            Spacer()

            Image(systemName: "sun.max.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
        }
        .frame(height: radius * 1.0)
    }

    private func label(for hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 6: return "6 AM"
        case 12: return "12 PM"
        case 18: return "6 PM"
        default: return "\(hour)"
        }
    }

    private func labelPosition(for angleDegrees: Double, distance: CGFloat) -> CGPoint {
        let rad = (angleDegrees - 90.0) * (.pi / 180.0)
        let center = CGPoint(x: radius, y: radius)
        let posX = center.x + distance * CGFloat(cos(rad))
        let posY = center.y + distance * CGFloat(sin(rad))
        return CGPoint(x: posX, y: posY)
    }
}

#Preview {
    DialFaceView(radius: 140, strokeWidth: 36)
        .padding()
}
