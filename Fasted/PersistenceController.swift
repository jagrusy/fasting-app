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

    public init(inMemory: Bool = false, storeURL: URL? = nil) {
        container = NSPersistentContainer(name: "Fasted")
        if let storeURL {
            container.persistentStoreDescriptions.first?.url = storeURL
        } else if inMemory {
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

    /// A store isolated from `.shared`, keyed by `identifier`.
    ///
    /// On-disk rather than in-memory: a UI test scenario terminates and relaunches the app to
    /// prove persistence, and the new process must reopen the *same* file to do that. Passing the
    /// same identifier across that relaunch keeps the file stable; a fresh identifier per test
    /// invocation keeps runs from bleeding into each other or into real user data.
    public static func uiTesting(storeIdentifier identifier: String) -> PersistenceController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uitest-\(identifier)", isDirectory: false)
            .appendingPathExtension("sqlite")
        return PersistenceController(storeURL: url)
    }

    public func saveContext() throws {
        let context = container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
}

/// Injectable Core Data boundaries used by `FastManager`.
///
/// Keeping object creation on the real context while injecting only the failure-prone I/O calls
/// lets tests exercise the same managed objects and rollback behavior as production.
struct FastManagerPersistence {
    var fetchFasts: (NSFetchRequest<Fast>) throws -> [Fast]
    var fetchSettings: (NSFetchRequest<UserSettings>) throws -> [UserSettings]
    var save: () throws -> Void
    var rollback: () -> Void

    init(context: NSManagedObjectContext) {
        fetchFasts = { try context.fetch($0) }
        fetchSettings = { try context.fetch($0) }
        save = { try context.save() }
        rollback = { context.rollback() }
    }
}
