import Foundation
import CoreGraphics

public struct DialMath {
    /// Converts a Date to an angle (in degrees, 0..360) on a 24-hour clock face.
    /// 0° (top) = 12:00 AM (midnight)
    /// 90° (right) = 6:00 AM
    /// 180° (bottom) = 12:00 PM (noon)
    /// 270° (left) = 6:00 PM
    public static func angle(for date: Date, calendar: Calendar = .current) -> Double {
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let second = Double(calendar.component(.second, from: date))
        let totalHours = hour + (minute / 60.0) + (second / 3600.0)
        return (totalHours / 24.0) * 360.0
    }

    /// Converts an angle (in degrees, 0..360) from top (0° = 12:00 AM) to the corresponding time on a base date.
    public static func date(
        from angle: Double,
        baseDate: Date,
        calendar: Calendar = .current,
        snapToMinutes: Int = 5
    ) -> Date {
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
        if normalizedAngle < 0 {
            normalizedAngle += 360.0
        }

        let totalSecondsInDay = 86400.0
        var secondsFromMidnight = (normalizedAngle / 360.0) * totalSecondsInDay

        if snapToMinutes > 0 {
            let snapSeconds = Double(snapToMinutes * 60)
            secondsFromMidnight = (secondsFromMidnight / snapSeconds).rounded() * snapSeconds
        }

        let startOfDay = calendar.startOfDay(for: baseDate)
        return startOfDay.addingTimeInterval(secondsFromMidnight)
    }

    /// Snaps a given date to the nearest interval of minutes (e.g. 5 minutes).
    public static func snap(date: Date, intervalMinutes: Int = 5, calendar: Calendar = .current) -> Date {
        guard intervalMinutes > 0 else { return date }
        let startOfDay = calendar.startOfDay(for: date)
        let elapsed = date.timeIntervalSince(startOfDay)
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        let roundedElapsed = (elapsed / intervalSeconds).rounded() * intervalSeconds
        return startOfDay.addingTimeInterval(roundedElapsed)
    }

    /// Snaps a duration (in seconds) to the nearest interval of minutes.
    ///
    /// Unlike `snap(date:intervalMinutes:)`, which snaps a wall-clock time against the start of its day,
    /// this rounds an elapsed duration on its own axis. Never returns a negative value.
    public static func snapInterval(_ seconds: TimeInterval, toMinutes minutes: Int = 5) -> TimeInterval {
        guard minutes > 0 else { return max(0, seconds) }
        let intervalSeconds = TimeInterval(minutes * 60)
        return max(0, (seconds / intervalSeconds).rounded() * intervalSeconds)
    }

    /// Converts a CGPoint relative to center into an angle in degrees [0, 360) where 0 is at top (12 o'clock).
    public static func touchAngle(point: CGPoint, center: CGPoint) -> Double {
        let deltaX = Double(point.x - center.x)
        let deltaY = Double(point.y - center.y)

        // atan2 gives 0 at positive X axis (3 o'clock)
        // increasing counter-clockwise or clockwise depending on Y axis.
        let radians = atan2(deltaY, deltaX)
        var degrees = radians * (180.0 / .pi)

        // Shift so that 12 o'clock (-90°) is 0°
        degrees += 90.0
        if degrees < 0 {
            degrees += 360.0
        }
        return degrees.truncatingRemainder(dividingBy: 360.0)
    }

    /// Calculates point on circle given center, radius, and 24h dial angle (0° = 12 o'clock top).
    public static func pointOnCircle(center: CGPoint, radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let standardAngleRad = (angleDegrees - 90.0) * (.pi / 180.0)
        let posX = center.x + radius * CGFloat(cos(standardAngleRad))
        let posY = center.y + radius * CGFloat(sin(standardAngleRad))
        return CGPoint(x: posX, y: posY)
    }

    /// Determines if an angle lies on the clockwise arc from startAngle to endAngle.
    public static func isAngle(
        _ angle: Double,
        between startAngle: Double,
        and endAngle: Double
    ) -> Bool {
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
        let normalizedStart = startAngle.truncatingRemainder(dividingBy: 360.0)
        let normalizedEnd = endAngle.truncatingRemainder(dividingBy: 360.0)

        if normalizedStart <= normalizedEnd {
            return normalizedAngle >= normalizedStart && normalizedAngle <= normalizedEnd
        } else {
            // Arc crosses midnight (0° / 360°)
            return normalizedAngle >= normalizedStart || normalizedAngle <= normalizedEnd
        }
    }

    /// Calculates the arc sweep angle (in degrees) in clockwise direction from startAngle to endAngle.
    public static func sweepAngle(from startAngle: Double, to endAngle: Double) -> Double {
        var diff = endAngle - startAngle
        while diff < 0 {
            diff += 360.0
        }
        return diff.truncatingRemainder(dividingBy: 360.0)
    }

    /// Computes end date given start date and duration.
    public static func computeEndDate(startDate: Date, duration: TimeInterval) -> Date {
        startDate.addingTimeInterval(duration)
    }

    /// Computes duration between start date and end date considering 24h cycle.
    public static func computeDuration(
        startAngle: Double,
        endAngle: Double
    ) -> TimeInterval {
        let sweep = sweepAngle(from: startAngle, to: endAngle)
        let hours = (sweep / 360.0) * 24.0
        let seconds = hours * 3600.0
        return max(1800.0, seconds)
    }
}
