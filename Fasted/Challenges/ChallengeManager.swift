import CoreData
import Foundation

/// Main actor observable manager for active and historical challenges.
@MainActor
final class ChallengeManager: ObservableObject {
    let store: ChallengeStore
    let preferences: ChallengePreferences
    var now: () -> Date

    @Published private(set) var activeChallenge: Challenge?
    @Published private(set) var archivedChallenges: [Challenge] = []
    @Published var errorMessage: String?

    @Published var isChallengesEnabled: Bool {
        didSet {
            preferences.isChallengesEnabled = isChallengesEnabled
        }
    }

    convenience init(
        coordinator: NSPersistentStoreCoordinator,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(coordinator: coordinator, preferences: ChallengePreferences.resolveDefault(), now: now)
    }

    init(
        coordinator: NSPersistentStoreCoordinator,
        preferences: ChallengePreferences,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = ChallengeStore(coordinator: coordinator, now: now)
        self.preferences = preferences
        self.now = now
        self.isChallengesEnabled = preferences.isChallengesEnabled
        refresh()
    }

    convenience init(
        container: NSPersistentContainer,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(
            coordinator: container.persistentStoreCoordinator,
            preferences: ChallengePreferences.resolveDefault(),
            now: now
        )
    }

    init(
        container: NSPersistentContainer,
        preferences: ChallengePreferences,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = ChallengeStore(coordinator: container.persistentStoreCoordinator, now: now)
        self.preferences = preferences
        self.now = now
        self.isChallengesEnabled = preferences.isChallengesEnabled
        refresh()
    }

    convenience init(
        store: ChallengeStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.init(store: store, preferences: ChallengePreferences.resolveDefault(), now: now)
    }

    init(
        store: ChallengeStore,
        preferences: ChallengePreferences,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.preferences = preferences
        self.now = now
        self.isChallengesEnabled = preferences.isChallengesEnabled
        refresh()
    }

    func refresh() {
        do {
            let instant = now()
            let all = try store.challenges()
            activeChallenge = all.first { $0.isActive(at: instant) }
            archivedChallenges = all.filter { !$0.isActive(at: instant) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func startChallenge(draft: ChallengeDraft, replacing: UUID? = nil) throws -> Challenge {
        do {
            let challenge = try store.start(draft, replacing: replacing)
            isChallengesEnabled = true
            refresh()
            return challenge
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func checkIn(commitmentID: UUID, on date: Date, status: ChallengeCheckInStatus?) throws {
        guard let challenge = activeChallenge else {
            let error = ChallengeError.staleChallenge
            errorMessage = error.localizedDescription
            throw error
        }
        do {
            try store.checkIn(challengeID: challenge.id, commitmentID: commitmentID, on: date, status: status)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func archive(challengeID: UUID) throws {
        do {
            try store.archive(challengeID: challengeID)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func scheduledCommitments(for date: Date) -> [ChallengeCommitment] {
        guard let activeChallenge else { return [] }
        let weekday = activeChallenge.calendar.component(.weekday, from: date)
        return activeChallenge.commitments.filter { $0.draft.weekdays.contains(weekday) }
    }

    func checkInStatus(for commitmentID: UUID, on date: Date) -> ChallengeCheckInStatus? {
        guard let activeChallenge else { return nil }
        let day = activeChallenge.calendar.startOfDay(for: date)
        return activeChallenge.checkIns.first { $0.commitmentID == commitmentID && $0.day == day }?.status
    }

    func isCompleted(commitmentID: UUID, on date: Date) -> Bool {
        checkInStatus(for: commitmentID, on: date) == .done
    }

    var currentDayNumber: Int? {
        guard let activeChallenge else { return nil }
        let start = activeChallenge.calendar.startOfDay(for: activeChallenge.startDate)
        let today = activeChallenge.calendar.startOfDay(for: now())
        let days = activeChallenge.calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return min(max(days + 1, 1), activeChallenge.dayCount)
    }

    var totalDays: Int? {
        activeChallenge?.dayCount
    }

    var dayProgressFraction: Double {
        guard let current = currentDayNumber, let total = totalDays, total > 0 else { return 0 }
        return min(max(Double(current) / Double(total), 0), 1.0)
    }

    func allScheduledDone(for date: Date) -> Bool {
        let scheduled = scheduledCommitments(for: date)
        guard !scheduled.isEmpty else { return false }
        return scheduled.allSatisfy { isCompleted(commitmentID: $0.id, on: date) }
    }
}
