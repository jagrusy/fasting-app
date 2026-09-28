import Foundation
import UserNotifications

/// Side effects stay injectable so failure tests never contact Watch or request a store review.
struct FastManagerEffects {
    var syncWatch: @MainActor (FastingStateSnapshot) -> Void
    var requestReview: @MainActor (Fast, [Fast]) -> Void

    static let live = FastManagerEffects(
        syncWatch: { WatchSessionManager.shared.syncSnapshotToWatch($0) },
        requestReview: { ReviewPromptManager.shared.checkAndPromptIfEligible(completedFast: $0, allCompletedFasts: $1) }
    )
}

/// Notification transport only; all scheduling logic remains in NotificationManager.
struct NotificationDelivery {
    var add: (UNNotificationRequest, @escaping (Error?) -> Void) -> Void
    var remove: ([String]) -> Void
    var register: (Set<UNNotificationCategory>) -> Void
    var requestAuthorization: (@escaping (Bool, Error?) -> Void) -> Void

    static let live = NotificationDelivery(
        add: { UNUserNotificationCenter.current().add($0, withCompletionHandler: $1) },
        remove: { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0) },
        register: { UNUserNotificationCenter.current().setNotificationCategories($0) },
        requestAuthorization: {
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge], completionHandler: $0
            )
        }
    )
}
