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

    /// Formats a date relative to `now` ("Today", "Yesterday", "Tomorrow") or as "Mon, Sep 14".
    public static func formatRelativeDay(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// Formats a weekday abbreviation such as "Wed".
    public static func formatShortWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    /// Formats a month and year such as "September 2026".
    public static func formatMonthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    /// Formats a short numeric date and shortened time, e.g. "9/14/26, 8:00 PM".
    public static func formatShortDateTime(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .shortened)
    }

    /// Truncates a date down to whole minutes (zeroing seconds and subseconds).
    public static func floorToMinute(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }
}
