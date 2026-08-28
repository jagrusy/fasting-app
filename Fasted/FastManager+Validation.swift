import Foundation
import CoreData

extension FastManager {
    public func validateInterval(
        startDate: Date,
        endDate: Date? = nil,
        excludingFastId: UUID? = nil
    ) -> (isValid: Bool, message: String?) {
        let now = Date()
        if startDate > now {
            return (false, "Start time cannot be in the future.")
        }
        if let end = endDate, end > now {
            return (false, "End time cannot be in the future.")
        }
        if let end = endDate, end <= startDate {
            return (false, "End time must be after the start time.")
        }

        let effectiveEnd = endDate ?? now
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        if let excludeId = excludingFastId {
            request.predicate = NSPredicate(format: "id != %@", excludeId as CVarArg)
        }

        guard let allFasts = try? viewContext.fetch(request) else {
            return (true, nil)
        }

        for other in allFasts {
            guard let otherStart = other.startDate else { continue }
            let otherEnd = other.endDate ?? now
            if startDate < otherEnd && effectiveEnd > otherStart {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return (false, "This time overlaps with another fast on \(formatter.string(from: otherStart)).")
            }
        }
        return (true, nil)
    }

    public func clearAllFastingData() {
        let request: NSFetchRequest<NSFetchRequestResult> = Fast.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [viewContext]
                )
            }
            activeFast = nil
            notificationManager.cancelGoalNotification()
            notificationManager.cancelRecurringReminders()
            clearAllSnoozeOffsets()
            self.objectWillChange.send()
        } catch {
            NSLog("Error clearing all fasting data: \(error)")
        }
    }
}
