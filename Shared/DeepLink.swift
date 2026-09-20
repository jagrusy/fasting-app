import Foundation

/// Where a tap on a widget, Live Activity, or Control Center tile should land inside the app.
///
/// Both endpoints are tab selections, not navigation pushes — `ContentView` has no per-fast
/// destination to route to, since the active fast is simply whatever `FastTrackerView` renders.
public enum DeepLink: String, Sendable {
    case fastTracker
    case history

    public static let scheme = "solstice"

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        return components.url ?? URL(fileURLWithPath: "/")
    }

    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host, let link = DeepLink(rawValue: host) else {
            return nil
        }
        self = link
    }

    /// The link to prefer for a tap outside any interactive control, given whether a fast is
    /// currently running.
    public static func forWidgetTap(isFasting: Bool) -> DeepLink {
        isFasting ? .fastTracker : .history
    }
}
