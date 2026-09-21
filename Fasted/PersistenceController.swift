import CoreData

public struct PersistenceController {
    public static let shared: PersistenceController = PersistenceController.makeShared()

    private static func makeShared() -> PersistenceController {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment

        if let storeName = environment["FASTED_TEST_STORE_NAME"] ?? arguments.element(after: "-testStoreName") {
            let sanitized = storeName.replacingOccurrences(of: "/", with: "_")
            let fileManager = FileManager.default
            let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let testStoreDir = supportDir.appendingPathComponent("TestStores", isDirectory: true)
            try? FileManager.default.createDirectory(at: testStoreDir, withIntermediateDirectories: true)
            let storeURL = testStoreDir.appendingPathComponent("\(sanitized).sqlite")

            if arguments.contains("-resetTestStore") {
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: storeURL)
                try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
            }

            return PersistenceController(storeURL: storeURL)
        }

        if arguments.contains("-inMemoryTestStore") {
            return PersistenceController(inMemory: true)
        }
        #endif

        return PersistenceController()
    }

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
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let storeURL = storeURL {
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
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

#if DEBUG
extension Array where Element == String {
    fileprivate func element(after flag: String) -> String? {
        guard let index = firstIndex(of: flag), index + 1 < count else { return nil }
        return self[index + 1]
    }
}
#endif
