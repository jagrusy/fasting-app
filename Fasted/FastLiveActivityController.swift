import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Mirrors the published snapshot onto a Live Activity.
///
/// Driven entirely from `publishSnapshot()`, which is the single point every state change already
/// funnels through, so there is no separate lifecycle to keep in sync. The elapsed clock is a
/// `Text(timerInterval:)` and ticks on its own; the gauges are static per content state and refresh
/// on the next publish.
@MainActor
public final class FastLiveActivityController {
    public static let shared = FastLiveActivityController()

    private var activity: Activity<FastActivityAttributes>?

    private init() {}

    private var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public func sync(with snapshot: FastingStateSnapshot, at date: Date = Date()) {
        guard isEnabled else { return }

        guard let state = FastActivityAttributes.ContentState(snapshot: snapshot, at: date) else {
            end()
            return
        }

        // A relaunch loses the in-memory handle while the activity itself survives, so adopt any
        // already-running one before requesting a second.
        if activity == nil {
            activity = Activity<FastActivityAttributes>.activities.first
        }

        if let activity = activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: staleDate(after: date))) }
        } else {
            start(state: state, snapshot: snapshot, at: date)
        }
    }

    private func start(state: FastActivityAttributes.ContentState, snapshot: FastingStateSnapshot, at date: Date) {
        let attributes = FastActivityAttributes(
            protocolType: snapshot.protocolType ?? FastingProtocol.default.ratioString
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate(after: date)),
                pushType: nil
            )
        } catch {
            NSLog("[Solstice] Could not start Live Activity: \(error)")
        }
    }

    public func end() {
        guard let activity = activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Marks the gauges as untrusted once they have drifted by roughly a percent of a typical goal.
    private func staleDate(after date: Date) -> Date {
        date.addingTimeInterval(15 * 60)
    }
}
#endif
