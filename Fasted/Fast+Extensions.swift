import Foundation
import CoreData

extension Fast {
    /// Start date of the fast, falling back to `createdAt` or current date if unset.
    public var resolvedStartDate: Date {
        startDate ?? createdAt ?? Date()
    }

    /// End date of the fast, or `now` if the fast is currently active.
    public func resolvedEndDate(relativeTo now: Date = Date()) -> Date {
        endDate ?? now
    }

    /// Total duration of the fast in seconds (always >= 0).
    public func duration(relativeTo now: Date = Date()) -> TimeInterval {
        max(0, resolvedEndDate(relativeTo: now).timeIntervalSince(resolvedStartDate))
    }

    /// Elapsed duration for completed fasts.
    public var elapsedDuration: TimeInterval {
        duration()
    }

    /// Whether this fast met its goal duration or was explicitly marked completed.
    public func isGoalMet(relativeTo now: Date = Date()) -> Bool {
        isCompleted || (duration(relativeTo: now) >= targetDuration)
    }

    /// Property shortcut for completed fasts.
    public var isGoalMet: Bool {
        isGoalMet()
    }

    /// Progress towards target goal (0.0 to 1.0+).
    public func progress(relativeTo now: Date = Date()) -> Double {
        guard targetDuration > 0 else { return 0.0 }
        return duration(relativeTo: now) / targetDuration
    }

    /// Progress towards target goal using current time.
    public var progress: Double {
        progress()
    }

    /// Formatted elapsed duration string, e.g. "16h 24m", "45m", "16h".
    public func formattedDuration(relativeTo now: Date = Date()) -> String {
        FastDurationFormatter.formatDuration(duration(relativeTo: now))
    }

    /// Formatted elapsed duration string for completed fasts.
    public var formattedDuration: String {
        formattedDuration()
    }

    /// Formatted goal duration string, e.g. "16h".
    public var formattedGoal: String {
        FastDurationFormatter.formatDuration(targetDuration)
    }

    /// Formatted date range, e.g. "Mon, Sep 14 · 8:00 PM – 12:00 PM".
    public func formattedDateRange(relativeTo now: Date = Date()) -> String {
        FastDurationFormatter.formatDateRange(start: resolvedStartDate, end: resolvedEndDate(relativeTo: now))
    }

    /// Formatted date range for completed fasts.
    public var formattedDateRange: String {
        formattedDateRange()
    }
}
