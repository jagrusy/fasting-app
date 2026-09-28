import CoreData
import Foundation

@MainActor
public final class MealStore {
    private let context: NSManagedObjectContext
    public let photoStorage: MealPhotoStorage
    private let now: () -> Date
    private let save: (NSManagedObjectContext) throws -> Void

    public init(
        coordinator: NSPersistentStoreCoordinator,
        photoStorage: MealPhotoStorage = MealPhotoStorage(),
        now: @escaping () -> Date = Date.init,
        save: @escaping (NSManagedObjectContext) throws -> Void = { try $0.save() }
    ) {
        self.context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.context.persistentStoreCoordinator = coordinator
        self.context.mergePolicy = NSErrorMergePolicy
        self.photoStorage = photoStorage
        self.now = now
        self.save = save
    }

    public convenience init(
        container: NSPersistentContainer,
        photoStorage: MealPhotoStorage = MealPhotoStorage(),
        now: @escaping () -> Date = Date.init,
        save: @escaping (NSManagedObjectContext) throws -> Void = { try $0.save() }
    ) {
        self.init(
            coordinator: container.persistentStoreCoordinator,
            photoStorage: photoStorage,
            now: now,
            save: save
        )
    }

    public func meals() throws -> [MealEntry] {
        context.reset()
        let request = NSFetchRequest<NSManagedObject>(entityName: "MealEntryRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "mealTime", ascending: false)]
        let records = try context.fetch(request)
        return records.compactMap(decodeMeal)
    }

    @discardableResult
    public func save(draft: MealDraft) throws -> MealEntry {
        guard draft.isValid else { throw MealError.invalidDraft }

        var savedPhotoFilenames: (filename: String, thumbnailFilename: String)?
        #if canImport(UIKit)
        if let image = draft.image {
            savedPhotoFilenames = try photoStorage.save(image: image)
        }
        #endif

        do {
            return try transaction {
                let instant = now()
                let mealRecord = NSEntityDescription.insertNewObject(
                    forEntityName: "MealEntryRecord",
                    into: context
                )
                let mealID = UUID()
                mealRecord.setValue(mealID, forKey: "id")
                mealRecord.setValue(draft.mealTime, forKey: "mealTime")
                mealRecord.setValue(draft.notes, forKey: "notes")
                mealRecord.setValue(instant, forKey: "createdAt")
                mealRecord.setValue(instant, forKey: "updatedAt")

                if let filenames = savedPhotoFilenames {
                    let attachRecord = NSEntityDescription.insertNewObject(
                        forEntityName: "MealAttachmentRecord",
                        into: context
                    )
                    attachRecord.setValue(UUID(), forKey: "id")
                    attachRecord.setValue(filenames.filename, forKey: "filename")
                    attachRecord.setValue(filenames.thumbnailFilename, forKey: "thumbnailFilename")
                    attachRecord.setValue(instant, forKey: "createdAt")
                    attachRecord.setValue(mealRecord, forKey: "meal")
                }

                guard let result = decodeMeal(mealRecord) else {
                    throw MealError.persistenceFailed("Failed to decode newly created meal record.")
                }
                try save(context)
                return result
            }
        } catch {
            // Clean up saved photos on failed transaction
            if let filenames = savedPhotoFilenames {
                photoStorage.delete(filename: filenames.filename, thumbnailFilename: filenames.thumbnailFilename)
            }
            throw error
        }
    }

    public func delete(mealID: UUID) throws {
        try transaction {
            let request = NSFetchRequest<NSManagedObject>(entityName: "MealEntryRecord")
            request.predicate = NSPredicate(format: "id == %@", mealID as CVarArg)
            guard let record = try context.fetch(request).first else {
                throw MealError.notFound
            }

            // Gather photo files to delete from disk
            var filesToDelete: [(filename: String, thumb: String?)] = []
            if let attachments = record.value(forKey: "attachments") as? Set<NSManagedObject> {
                for att in attachments {
                    if let filename = att.value(forKey: "filename") as? String {
                        let thumb = att.value(forKey: "thumbnailFilename") as? String
                        filesToDelete.append((filename, thumb))
                    }
                }
            }

            context.delete(record)
            try save(context)

            // Remove files from disk after DB deletion succeeds
            for file in filesToDelete {
                photoStorage.delete(filename: file.filename, thumbnailFilename: file.thumb)
            }
        }
    }

    public func update(mealID: UUID, mealTime: Date, notes: String?) throws {
        try transaction {
            let request = NSFetchRequest<NSManagedObject>(entityName: "MealEntryRecord")
            request.predicate = NSPredicate(format: "id == %@", mealID as CVarArg)
            guard let record = try context.fetch(request).first else {
                throw MealError.notFound
            }
            record.setValue(mealTime, forKey: "mealTime")
            record.setValue(notes, forKey: "notes")
            record.setValue(now(), forKey: "updatedAt")
            try save(context)
        }
    }

    public func cleanupOrphans() throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "MealAttachmentRecord")
        let attachments = try context.fetch(request)
        var referenced = Set<String>()
        for att in attachments {
            if let filename = att.value(forKey: "filename") as? String {
                referenced.insert(filename)
            }
            if let thumb = att.value(forKey: "thumbnailFilename") as? String {
                referenced.insert(thumb)
            }
        }
        photoStorage.cleanupOrphans(referencedFilenames: referenced)
    }

    private func decodeMeal(_ record: NSManagedObject) -> MealEntry? {
        guard let id = record.value(forKey: "id") as? UUID,
              let mealTime = record.value(forKey: "mealTime") as? Date,
              let createdAt = record.value(forKey: "createdAt") as? Date,
              let updatedAt = record.value(forKey: "updatedAt") as? Date
        else { return nil }

        let notes = record.value(forKey: "notes") as? String
        var attachments: [MealAttachment] = []
        if let rawAttachments = record.value(forKey: "attachments") as? Set<NSManagedObject> {
            for att in rawAttachments {
                if let attID = att.value(forKey: "id") as? UUID,
                   let filename = att.value(forKey: "filename") as? String,
                   let attCreated = att.value(forKey: "createdAt") as? Date {
                    let thumb = att.value(forKey: "thumbnailFilename") as? String
                    attachments.append(MealAttachment(
                        id: attID,
                        filename: filename,
                        thumbnailFilename: thumb,
                        createdAt: attCreated
                    ))
                }
            }
        }
        attachments.sort { $0.createdAt < $1.createdAt }

        return MealEntry(
            id: id,
            mealTime: mealTime,
            notes: notes,
            attachments: attachments,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func transaction<T>(_ work: () throws -> T) throws -> T {
        do {
            let result = try work()
            return result
        } catch {
            context.rollback()
            throw error
        }
    }
}
