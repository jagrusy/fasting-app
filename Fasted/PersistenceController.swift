import CoreData

public struct PersistenceController {
    public static let shared = PersistenceController()

    public static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Seed mock fast
        let sampleFast = Fast(context: viewContext)
        sampleFast.id = UUID()
        sampleFast.startDate = Date().addingTimeInterval(-14 * 3600)
        sampleFast.targetDuration = 16 * 3600
        sampleFast.protocolType = "16:8"
        sampleFast.isCompleted = false
        sampleFast.createdAt = sampleFast.startDate
        sampleFast.updatedAt = Date()

        // Seed mock settings
        let settings = UserSettings(context: viewContext)
        settings.id = UUID()
        settings.selectedProtocol = "16:8"
        settings.notificationsEnabled = false

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    public let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Fasted")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                NSLog("Unresolved Core Data save error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
