import CoreData
import Foundation

public struct FastingMealOverlap: Identifiable {
    public let id = UUID()
    public let meal: MealEntry
    public let activeFastStartDate: Date
    public let activeFastId: UUID?

    public init(meal: MealEntry, activeFastStartDate: Date, activeFastId: UUID?) {
        self.meal = meal
        self.activeFastStartDate = activeFastStartDate
        self.activeFastId = activeFastId
    }
}

@MainActor
public final class MealManager: ObservableObject {
    public let store: MealStore
    public let preferences: JournalPreferences
    public var now: () -> Date

    @Published public private(set) var meals: [MealEntry] = []
    @Published public var errorMessage: String?

    @Published public var isJournalEnabled: Bool {
        didSet {
            preferences.isJournalEnabled = isJournalEnabled
        }
    }

    @Published public var postFastPromptEnabled: Bool {
        didSet {
            preferences.postFastPromptEnabled = postFastPromptEnabled
        }
    }

    @Published public var hasDeclinedPostFastPromptPermanently: Bool {
        didSet {
            preferences.hasDeclinedPostFastPromptPermanently = hasDeclinedPostFastPromptPermanently
        }
    }

    // Post-fast composer trigger
    @Published public var showPostFastComposer: Bool = false
    @Published public var postFastComposerMealTime: Date?

    // Overlap prompt when meal logged during fast
    @Published public var fastingOverlapConfirmation: FastingMealOverlap?

    public convenience init(
        coordinator: NSPersistentStoreCoordinator,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(
            coordinator: coordinator,
            preferences: JournalPreferences.resolveDefault(),
            photoStorage: MealPhotoStorage(),
            now: now
        )
    }

    public init(
        coordinator: NSPersistentStoreCoordinator,
        preferences: JournalPreferences,
        photoStorage: MealPhotoStorage = MealPhotoStorage(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = MealStore(coordinator: coordinator, photoStorage: photoStorage, now: now)
        self.preferences = preferences
        self.now = now
        self.isJournalEnabled = preferences.isJournalEnabled
        self.postFastPromptEnabled = preferences.postFastPromptEnabled
        self.hasDeclinedPostFastPromptPermanently = preferences.hasDeclinedPostFastPromptPermanently
        refresh()
    }

    public convenience init(
        container: NSPersistentContainer,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(
            coordinator: container.persistentStoreCoordinator,
            preferences: JournalPreferences.resolveDefault(),
            photoStorage: MealPhotoStorage(),
            now: now
        )
    }

    public convenience init(
        container: NSPersistentContainer,
        preferences: JournalPreferences,
        photoStorage: MealPhotoStorage = MealPhotoStorage(),
        now: @escaping () -> Date = Date.init
    ) {
        self.init(
            coordinator: container.persistentStoreCoordinator,
            preferences: preferences,
            photoStorage: photoStorage,
            now: now
        )
    }

    public convenience init(
        store: MealStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(
            store: store,
            preferences: JournalPreferences.resolveDefault(),
            now: now
        )
    }

    public init(
        store: MealStore,
        preferences: JournalPreferences,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.preferences = preferences
        self.now = now
        self.isJournalEnabled = preferences.isJournalEnabled
        self.postFastPromptEnabled = preferences.postFastPromptEnabled
        self.hasDeclinedPostFastPromptPermanently = preferences.hasDeclinedPostFastPromptPermanently
        refresh()
    }

    public func refresh() {
        do {
            meals = try store.meals()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    public func saveMeal(
        draft: MealDraft,
        activeFast: Fast? = nil
    ) throws -> MealEntry {
        do {
            let meal = try store.save(draft: draft)
            refresh()

            // Check if eaten during currently active fast
            if let activeFast, let fastStart = activeFast.startDate {
                let currentInstant = now()
                if draft.mealTime >= fastStart && draft.mealTime <= currentInstant {
                    fastingOverlapConfirmation = FastingMealOverlap(
                        meal: meal,
                        activeFastStartDate: fastStart,
                        activeFastId: activeFast.id
                    )
                }
            }
            return meal
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func deleteMeal(id: UUID) throws {
        do {
            try store.delete(mealID: id)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func handleFastEnded(endDate: Date) {
        guard isJournalEnabled,
              postFastPromptEnabled,
              !hasDeclinedPostFastPromptPermanently else {
            return
        }
        postFastComposerMealTime = endDate
        showPostFastComposer = true
    }

    public func declinePostFastPromptPermanently() {
        hasDeclinedPostFastPromptPermanently = true
        postFastPromptEnabled = false
        showPostFastComposer = false
    }
}
