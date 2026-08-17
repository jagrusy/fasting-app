import SwiftUI

public struct FastingArcShape: Shape {
    public var startAngle: Double // in degrees [0, 360), 0 is top
    public var endAngle: Double   // in degrees [0, 360), 0 is top

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Convert our 0°-is-top angles to standard iOS angles (0° is 3 o'clock)
        let standardStart = Angle.degrees(startAngle - 90.0)
        let standardEnd = Angle.degrees(endAngle - 90.0)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: standardStart,
            endAngle: standardEnd,
            clockwise: false // false in iOS draws clockwise in visual coordinate space
        )
        return path
    }
}
