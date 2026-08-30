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

    /// Applies commands enqueued by the widget, Control Center, a notification action, or the
    /// watch. Core Data is unreachable from those processes, so the queue is the only durable
    /// channel — but a command can also be arbitrarily *stale* by the time it lands here
    /// (`transferUserInfo` from an out-of-range watch is delivered whenever the phone next runs).
    /// Every command is therefore re-validated against current state rather than trusted.
    public func processPendingCommands() {
        // The scene-phase hook and the Darwin observer can both fire; a nested drain would see an
        // already-emptied queue, but the flag keeps the Core Data writes strictly serialized.
        guard !isDrainingCommands else { return }
        isDrainingCommands = true
        defer { isDrainingCommands = false }

        let pending = coordinator.drainPendingCommands()
        guard !pending.isEmpty else { return }

        // Deliveries can interleave (App Group queue vs. WatchConnectivity), so order by the
        // moment of the tap, not the moment of arrival.
        for envelope in pending.sorted(by: { $0.timestamp < $1.timestamp }) {
            apply(envelope.command)
        }
        publishSnapshot()
    }

    private func apply(_ command: FastingActionCommand) {
        switch command {
        case .startFast(let startDate, let duration, let proto):
            guard activeFast == nil, validateInterval(startDate: startDate).isValid else { return }
            startFast(startDate: startDate, targetDuration: duration, protocolType: proto)
        case .endFast(let endDate):
            // A stale end can arrive after the phone already ended that fast and started a new
            // one; applying it verbatim would write an endDate before the startDate.
            guard let start = activeFast?.startDate, endDate > start else { return }
            endFast(endDate: endDate)
        case .snoozeFast(let extensionSeconds):
            guard activeFast != nil else { return }
            snoozeFast(by: extensionSeconds)
        }
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
