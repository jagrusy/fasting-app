import Foundation

public enum FastDurationFormatter {
    /// Formats any interval in human-readable fasting format: "16h 24m", "45m", "16h", or "0m".
    public static func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(0, interval) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }

    /// Formats interval as a digital clock: "16:24:00", "00:45:12".
    public static func formatClock(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Formats a date range: "Mon, Sep 14 · 8:00 PM – 12:00 PM".
    public static func formatDateRange(start: Date, end: Date) -> String {
        let dayStr = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let startTimeStr = formatTime(start)
        let endTimeStr = formatTime(end)
        return "\(dayStr) · \(startTimeStr) – \(endTimeStr)"
    }

    /// Formats a time: "8:00 PM".
    public static func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
