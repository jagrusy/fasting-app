import Foundation
import CoreData

extension FastManager {
    public func clearOperationError() {
        operationError = nil
    }

    @discardableResult
    func fail(_ error: Error, operation: String, rollback: Bool = true) -> Bool {
        if rollback {
            persistence.rollback()
        }
        NSLog("[Solstice] \(operation) failed: \(error)")
        let message = "Solstice couldn't \(operation.lowercased()). "
            + "Your saved fasting data is unchanged. Please try again."
        operationError = FastManagerOperationError(message: message)
        return false
    }

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

        let allFasts: [Fast]
        do {
            allFasts = try persistence.fetchFasts(request)
        } catch {
            _ = fail(error, operation: "Validate the fasting time", rollback: false)
            return (false, "Solstice couldn't verify this time against your history. Please try again.")
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

    @discardableResult
    public func clearAllFastingData() -> Bool {
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
            publishSnapshot()
            return true
        } catch {
            return fail(error, operation: "Erase fasting data")
        }
    }
}
