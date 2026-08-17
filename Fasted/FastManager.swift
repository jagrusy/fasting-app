import Foundation
import CoreData
import SwiftUI

@MainActor
public final class FastManager: ObservableObject {
    private let viewContext: NSManagedObjectContext

    @Published public private(set) var activeFast: Fast?
    @Published public private(set) var userSettings: UserSettings?

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        self.refresh()
    }

    public func refresh() {
        fetchActiveFast()
        fetchUserSettings()
    }

    public func fetchActiveFast() {
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        request.predicate = NSPredicate(format: "endDate == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Fast.startDate, ascending: false)]
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            self.activeFast = results.first
        } catch {
            NSLog("Failed to fetch active fast: \(error)")
            self.activeFast = nil
        }
    }

    public func fetchUserSettings() {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            if let existing = results.first {
                self.userSettings = existing
            } else {
                let initial = UserSettings(context: viewContext)
                initial.id = UUID()
                initial.selectedProtocol = FastingProtocol.default.ratioString
                initial.notificationsEnabled = false
                try? viewContext.save()
                self.userSettings = initial
            }
        } catch {
            NSLog("Failed to fetch UserSettings: \(error)")
        }
    }

    public var currentProtocol: FastingProtocol {
        FastingProtocol.from(protocolType: userSettings?.selectedProtocol)
    }

    public var isFasting: Bool {
        activeFast != nil
    }

    @discardableResult
    public func startFast(
        startDate: Date = Date(),
        targetDuration: TimeInterval? = nil,
        protocolType: String? = nil
    ) -> Fast {
        // If there is already an active fast, return it
        if let existing = activeFast {
            return existing
        }

        let proto = protocolType ?? currentProtocol.ratioString
        let duration = targetDuration ?? FastingProtocol.from(protocolType: proto).fastingSeconds

        let fast = Fast(context: viewContext)
        fast.id = UUID()
        fast.startDate = startDate
        fast.targetDuration = duration
        fast.protocolType = proto
        fast.isCompleted = false
        fast.createdAt = Date()
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.activeFast = fast
        } catch {
            NSLog("Error starting fast: \(error)")
        }
        return fast
    }

    public func endFast(endDate: Date = Date(), moodRating: Int16? = nil) {
        guard let fast = activeFast else { return }

        let start = fast.startDate ?? Date()
        fast.endDate = endDate
        fast.isCompleted = (endDate.timeIntervalSince(start) >= fast.targetDuration)
        if let mood = moodRating {
            fast.moodRating = mood
        }
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.activeFast = nil
        } catch {
            NSLog("Error ending fast: \(error)")
        }
    }

    public func updateActiveFast(startDate: Date, targetDuration: TimeInterval) {
        guard let fast = activeFast else { return }
        fast.startDate = startDate
        fast.targetDuration = targetDuration
        fast.updatedAt = Date()

        do {
            try viewContext.save()
            self.objectWillChange.send()
        } catch {
            NSLog("Error updating active fast: \(error)")
        }
    }

    public func deleteFast(_ fast: Fast) {
        if activeFast?.id == fast.id {
            activeFast = nil
        }
        viewContext.delete(fast)

        do {
            try viewContext.save()
            self.objectWillChange.send()
        } catch {
            NSLog("Error deleting fast: \(error)")
        }
    }
}
