import CoreData
import XCTest
@testable import Fasted

@MainActor
final class MealStoreTests: XCTestCase {
    private var container: NSPersistentContainer?
    private var photoStorage: MealPhotoStorage?
    private var tempDirectory: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meal_store_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectory = dir
        photoStorage = MealPhotoStorage(directoryURL: dir)

        let model = PersistenceController.shared.container.managedObjectModel
        let cont = NSPersistentContainer(name: "Fasted", managedObjectModel: model)
        cont.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        cont.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        container = cont
    }

    override func tearDownWithError() throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        container = nil
        photoStorage = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }

    private func createSampleImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testSaveTextOnlyMeal() throws {
        let cont = try XCTUnwrap(container)
        let storage = try XCTUnwrap(photoStorage)
        let store = MealStore(container: cont, photoStorage: storage)
        let draft = MealDraft(mealTime: Date(), notes: "Avocado toast with eggs")

        let meal = try store.save(draft: draft)
        XCTAssertEqual(meal.notes, "Avocado toast with eggs")
        XCTAssertFalse(meal.hasPhoto)
        XCTAssertTrue(meal.attachments.isEmpty)

        let all = try store.meals()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, meal.id)
    }

    func testSaveMealWithPhotoCreatesFilesOnDisk() throws {
        let cont = try XCTUnwrap(container)
        let storage = try XCTUnwrap(photoStorage)
        let store = MealStore(container: cont, photoStorage: storage)
        let image = createSampleImage()
        let draft = MealDraft(mealTime: Date(), notes: "Lunch salad", image: image)

        let meal = try store.save(draft: draft)
        XCTAssertTrue(meal.hasPhoto)
        XCTAssertEqual(meal.attachments.count, 1)

        let attachment = try XCTUnwrap(meal.attachments.first)
        let photoURL = storage.fileURL(for: attachment.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoURL.path))

        if let thumb = attachment.thumbnailFilename {
            let thumbURL = storage.fileURL(for: thumb)
            XCTAssertTrue(FileManager.default.fileExists(atPath: thumbURL.path))
        }

        let loaded = try store.meals()
        XCTAssertEqual(loaded.first?.attachments.count, 1)
    }

    func testDeleteMealPurgesRecordAndFiles() throws {
        let cont = try XCTUnwrap(container)
        let storage = try XCTUnwrap(photoStorage)
        let store = MealStore(container: cont, photoStorage: storage)
        let image = createSampleImage()
        let draft = MealDraft(mealTime: Date(), notes: "Dinner steak", image: image)

        let meal = try store.save(draft: draft)
        let attachment = try XCTUnwrap(meal.attachments.first)
        let photoURL = storage.fileURL(for: attachment.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoURL.path))

        try store.delete(mealID: meal.id)

        let all = try store.meals()
        XCTAssertTrue(all.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoURL.path))
    }

    func testInvalidDraftThrows() throws {
        let cont = try XCTUnwrap(container)
        let storage = try XCTUnwrap(photoStorage)
        let store = MealStore(container: cont, photoStorage: storage)
        let emptyDraft = MealDraft(mealTime: Date(), notes: "   ", image: nil)

        XCTAssertThrowsError(try store.save(draft: emptyDraft)) { error in
            XCTAssertEqual(error as? MealError, MealError.invalidDraft)
        }
    }

    func testRollbackCleansUpWrittenPhotosOnSaveError() throws {
        let cont = try XCTUnwrap(container)
        let storage = try XCTUnwrap(photoStorage)
        let dir = try XCTUnwrap(tempDirectory)
        let injectedError = NSError(domain: "test", code: 42, userInfo: nil)
        let store = MealStore(
            coordinator: cont.persistentStoreCoordinator,
            photoStorage: storage,
            save: { _ in throw injectedError }
        )

        let image = createSampleImage()
        let draft = MealDraft(mealTime: Date(), notes: "Should fail", image: image)

        XCTAssertThrowsError(try store.save(draft: draft))

        // Ensure no leftover files in directory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        XCTAssertTrue(files.isEmpty, "Temporary photos must be purged if database save fails")
    }

    func testOrphanPhotoCleanup() throws {
        let cont = try XCTUnwrap(container)
        let storage = try XCTUnwrap(photoStorage)
        let dir = try XCTUnwrap(tempDirectory)
        let store = MealStore(container: cont, photoStorage: storage)
        let image = createSampleImage()
        _ = try store.save(draft: MealDraft(mealTime: Date(), notes: "Legit meal", image: image))

        // Create an orphan file manually
        let orphanURL = dir.appendingPathComponent("orphan_photo.jpg")
        try "test data".write(to: orphanURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanURL.path))

        try store.cleanupOrphans()

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanURL.path), "Orphan photo must be cleaned up")
        let legitFiles = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertFalse(legitFiles.isEmpty, "Legit meal photos must remain intact")
    }
}
