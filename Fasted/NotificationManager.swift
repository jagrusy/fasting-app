import Foundation
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    public static let goalReachedCategoryId = "FAST_GOAL_CATEGORY"
    public static let endFastActionId = "END_FAST_ACTION"
    public static let snooze30MinActionId = "SNOOZE_30MIN_ACTION"
    public static let snooze1HourActionId = "SNOOZE_1HOUR_ACTION"

    public static let startFastCategoryId = "START_FAST_CATEGORY"
    public static let startFastActionId = "START_FAST_ACTION"

    public var onStartFastRequested: (@MainActor () -> Void)?
    public var onEndFastRequested: (@MainActor () -> Void)?
    public var onSnoozeRequested: (@MainActor (TimeInterval) -> Void)?
    public var isCurrentlyFasting: (() -> Bool)?

    let delivery: NotificationDelivery

    private override convenience init() {
        self.init(delivery: .live)
        UNUserNotificationCenter.current().delegate = self
    }

    init(delivery: NotificationDelivery) {
        self.delivery = delivery
        super.init()
        registerCategories()
    }

    public func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        delivery.requestAuthorization { granted, error in
            if let error = error {
                NSLog("Notification authorization error: \(error)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    public func registerCategories() {
        let endAction = UNNotificationAction(
            identifier: NotificationManager.endFastActionId,
            title: "End Fast",
            options: [.destructive, .authenticationRequired]
        )

        let snooze30 = UNNotificationAction(
            identifier: NotificationManager.snooze30MinActionId,
            title: "Snooze (30m)",
            options: []
        )

        let snooze1h = UNNotificationAction(
            identifier: NotificationManager.snooze1HourActionId,
            title: "Snooze (1h)",
            options: []
        )

        let goalCategory = UNNotificationCategory(
            identifier: NotificationManager.goalReachedCategoryId,
            actions: [endAction, snooze30, snooze1h],
            intentIdentifiers: [],
            options: []
        )

        let startAction = UNNotificationAction(
            identifier: NotificationManager.startFastActionId,
            title: "Start Fast",
            options: [.authenticationRequired]
        )

        let startCategory = UNNotificationCategory(
            identifier: NotificationManager.startFastCategoryId,
            actions: [startAction],
            intentIdentifiers: [],
            options: []
        )

        delivery.register([goalCategory, startCategory])
    }

    public func scheduleGoalNotification(targetEndDate: Date, protocolName: String, enabled: Bool = true) {
        cancelGoalNotification()
        guard enabled else { return }

        let timeInterval = targetEndDate.timeIntervalSinceNow
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fasting Goal Reached! 🎉"
        content.body = "You completed your \(protocolName) fast. Ready to break your fast?"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.goalReachedCategoryId

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "fast_goal_notification", content: content, trigger: trigger)

        delivery.add(request) { error in
            if let error = error {
                NSLog("Failed to schedule goal notification: \(error)")
            }
        }
    }

    public func cancelGoalNotification() {
        let identifiers = ["fast_goal_notification"]
        delivery.remove(identifiers)
    }

    // MARK: - Stage Transition Notifications

    public struct StageBoundary: Equatable {
        public let stage: MetabolicStage
        public let fireDate: Date
        public let timeInterval: TimeInterval

        public init(stage: MetabolicStage, fireDate: Date, timeInterval: TimeInterval) {
            self.stage = stage
            self.fireDate = fireDate
            self.timeInterval = timeInterval
        }
    }

    public static func stageNotificationIdentifier(for stage: MetabolicStage) -> String {
        "fast_stage_\(stage.rawValue)"
    }

    public static func futureStageBoundaries(
        startDate: Date,
        now: Date = Date()
    ) -> [StageBoundary] {
        MetabolicStage.allCases
            .filter { $0.startSeconds > 0 }
            .compactMap { stage in
                let fireDate = startDate.addingTimeInterval(stage.startSeconds)
                let interval = fireDate.timeIntervalSince(now)
                guard interval > 0 else { return nil }
                return StageBoundary(stage: stage, fireDate: fireDate, timeInterval: interval)
            }
    }

    /// Stage transitions, plus day milestones when `targetDuration` is given.
    public func scheduleStageTransitionNotifications(
        startDate: Date,
        targetDuration: TimeInterval? = nil,
        enabled: Bool = true,
        now: Date = Date()
    ) {
        cancelStageTransitionNotifications()
        guard enabled else { return }

        if let target = targetDuration {
            for milestone in Self.futureDayMilestones(startDate: startDate, targetDuration: target, now: now) {
                let content = UNMutableNotificationContent()
                content.title = "\(milestone.hours) Hours Fasted"
                content.body = "\(milestone.hoursRemaining) hours to go. Keep it up!"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: milestone.timeInterval, repeats: false)
                let identifier = Self.dayMilestoneIdentifier(forDay: milestone.hours / 24)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                delivery.add(request) { error in
                    if let error = error {
                        NSLog("Failed to schedule day milestone \(identifier): \(error)")
                    }
                }
            }
        }

        let boundaries = Self.futureStageBoundaries(startDate: startDate, now: now)
        for item in boundaries {
            let content = UNMutableNotificationContent()
            content.title = item.stage.title
            content.body = item.stage.summary
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.timeInterval, repeats: false)
            let identifier = Self.stageNotificationIdentifier(for: item.stage)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            delivery.add(request) { error in
                if let error = error {
                    NSLog("Failed to schedule stage notification \(identifier): \(error)")
                }
            }
        }
    }

    /// Also cancels day milestones, which share the stage-change setting and lifetime.
    public func cancelStageTransitionNotifications() {
        let identifiers = MetabolicStage.allCases.map { Self.stageNotificationIdentifier(for: $0) }
            + (1...Self.maxDayMilestones).map { Self.dayMilestoneIdentifier(forDay: $0) }
        delivery.remove(identifiers)
    }

    // UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        DispatchQueue.main.async { [weak self] in
            switch actionId {
            case NotificationManager.startFastActionId:
                if let handler = self?.onStartFastRequested {
                    handler()
                } else {
                    let proto = AppGroupCoordinator.shared.readSnapshot().resolvedProtocol
                    AppGroupCoordinator.shared.enqueueCommand(
                        .startFast(
                            startDate: Date(),
                            duration: proto.fastingSeconds,
                            protocolType: proto.ratioString
                        )
                    )
                }
            case NotificationManager.endFastActionId:
                if let handler = self?.onEndFastRequested {
                    handler()
                } else {
                    AppGroupCoordinator.shared.enqueueCommand(.endFast(endDate: Date()))
                }
            case NotificationManager.snooze30MinActionId:
                if let handler = self?.onSnoozeRequested {
                    handler(30 * 60)
                } else {
                    AppGroupCoordinator.shared.enqueueCommand(.snoozeFast(extensionSeconds: 30 * 60))
                }
            case NotificationManager.snooze1HourActionId:
                if let handler = self?.onSnoozeRequested {
                    handler(60 * 60)
                } else {
                    AppGroupCoordinator.shared.enqueueCommand(.snoozeFast(extensionSeconds: 60 * 60))
                }
            default:
                break
            }
            completionHandler()
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let isStartReminder = content.categoryIdentifier == NotificationManager.startFastCategoryId
            || notification.request.identifier.hasPrefix(FastingReminderIDs.startReminderPrefix)
        if isStartReminder {
            let fasting = isCurrentlyFasting?() ?? AppGroupCoordinator.shared.readSnapshot().isFasting
            if fasting {
                completionHandler([])
                return
            }
        }
        completionHandler([.banner, .sound, .badge])
    }
}
