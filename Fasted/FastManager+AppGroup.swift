import Foundation
import CoreData

extension FastManager {
    public func publishSnapshot() {
        let allCompletedRequest: NSFetchRequest<Fast> = Fast.fetchRequest()
        allCompletedRequest.predicate = NSPredicate(format: "endDate != nil AND isCompleted == YES")
        allCompletedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Fast.endDate, ascending: false)]
        let completedFasts = (try? viewContext.fetch(allCompletedRequest)) ?? []

        let streakInfo = StreakCalculator.calculate(from: completedFasts)
        let lastCompletedDate = completedFasts.first?.endDate

        let snapshot: FastingStateSnapshot
        if let fast = activeFast, let start = fast.startDate {
            snapshot = FastingStateSnapshot(
                isFasting: true,
                startDate: start,
                targetDuration: fast.targetDuration + snoozeOffset(for: fast),
                protocolType: fast.protocolType ?? currentProtocol.ratioString,
                currentStreak: streakInfo.currentStreak,
                longestStreak: streakInfo.bestStreak,
                lastCompletedFastDate: lastCompletedDate,
                updatedAt: Date()
            )
        } else {
            snapshot = FastingStateSnapshot(
                isFasting: false,
                startDate: nil,
                targetDuration: nil,
                protocolType: currentProtocol.ratioString,
                currentStreak: streakInfo.currentStreak,
                longestStreak: streakInfo.bestStreak,
                lastCompletedFastDate: lastCompletedDate,
                updatedAt: Date()
            )
        }

        coordinator.writeSnapshot(snapshot)
        WatchSessionManager.shared.syncSnapshotToWatch(snapshot)
    }

    public func processPendingCommands() {

        let pending = coordinator.drainPendingCommands()
        guard !pending.isEmpty else { return }

        for envelope in pending {
            switch envelope.command {
            case .startFast(let startDate, let duration, let proto):
                if activeFast == nil {
                    startFast(startDate: startDate, targetDuration: duration, protocolType: proto)
                }
            case .endFast(let endDate):
                if activeFast != nil {
                    endFast(endDate: endDate)
                }
            case .snoozeFast(let extensionSeconds):
                if activeFast != nil {
                    snoozeFast(by: extensionSeconds)
                }
            }
        }
        publishSnapshot()
    }

    /// Ends the current fast without saving it to history — used when the user explicitly discards
    /// an early end rather than saving a partial fast.
    public func discardActiveFast() {
        guard let fast = activeFast else { return }
        deleteFast(fast)
    }

    public func updateCompletedFast(
        _ fast: Fast,
        startDate: Date,
        endDate: Date
    ) {
        fast.startDate = startDate
        fast.endDate = endDate
        let elapsed = endDate.timeIntervalSince(startDate)
        fast.isCompleted = (elapsed >= fast.targetDuration)
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.objectWillChange.send()
            publishSnapshot()
        } catch {
            NSLog("Error updating completed fast: \(error)")
        }
    }

    public func deleteFast(_ fast: Fast) {
        if let active = activeFast, active === fast {
            activeFast = nil
            notificationManager.cancelGoalNotification()
            notificationManager.cancelStageTransitionNotifications()
        }
        clearSnoozeOffset(for: fast)
        viewContext.delete(fast)

        do {
            try viewContext.save()
            self.objectWillChange.send()
            publishSnapshot()
        } catch {
            NSLog("Error deleting fast: \(error)")
        }
    }
}
