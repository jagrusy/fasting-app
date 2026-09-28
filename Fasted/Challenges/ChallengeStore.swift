import CoreData

/// One foreground writer. Its private context never saves or rolls back the fasting UI's pending edits.
@MainActor
final class ChallengeStore {
    private let context: NSManagedObjectContext
    private let now: () -> Date
    private let save: (NSManagedObjectContext) throws -> Void

    init(
        coordinator: NSPersistentStoreCoordinator,
        now: @escaping () -> Date = Date.init,
        save: @escaping (NSManagedObjectContext) throws -> Void = { try $0.save() }
    ) {
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSErrorMergePolicy
        self.now = now
        self.save = save
    }

    convenience init(
        container: NSPersistentContainer,
        now: @escaping () -> Date = Date.init,
        save: @escaping (NSManagedObjectContext) throws -> Void = { try $0.save() }
    ) {
        self.init(coordinator: container.persistentStoreCoordinator, now: now, save: save)
    }

    func challenges() throws -> [Challenge] {
        context.reset()
        return try records().map(Challenge.decode)
    }

    /// Replacement requires the ID the user reviewed; cancellation never calls this method.
    @discardableResult
    func start(_ input: ChallengeDraft, replacing expectedID: UUID? = nil) throws -> Challenge {
        let draft = try input.validated()
        return try transaction {
            let instant = now()
            let existing = try records()
            let active = try existing.filter { try Challenge.decode($0).isActive(at: instant) }
            guard active.count <= 1 else { throw ChallengeError.corruptStore }
            if let current = active.first {
                guard expectedID != nil else { throw ChallengeError.alreadyActive }
                guard current.value(forKey: "id") as? UUID == expectedID else { throw ChallengeError.staleChallenge }
                current.setValue(instant, forKey: "endedAt")
            } else if expectedID != nil {
                throw ChallengeError.staleChallenge
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: draft.timeZoneID) ?? .current
            let record = NSEntityDescription.insertNewObject(forEntityName: "ChallengeRecord", into: context)
            record.setValuesForKeys([
                "id": UUID(), "title": draft.title, "startDate": calendar.startOfDay(for: instant),
                "dayCount": draft.dayCount, "timeZoneID": draft.timeZoneID, "createdAt": instant
            ])
            record.setValue(draft.reason, forKey: "reason")
            for (position, commitment) in draft.commitments.enumerated() {
                insert(commitment, position: position, into: record)
            }
            // Decode before commit so a malformed transaction cannot be reported as a successful save.
            let result = try Challenge.decode(record)
            try save(context)
            return result
        }
    }

    /// Archives an active challenge early, recording `endedAt`. Preserves all records.
    func archive(challengeID: UUID) throws {
        try transaction {
            let instant = now()
            guard let record = try records().first(where: { $0.value(forKey: "id") as? UUID == challengeID })
            else { throw ChallengeError.staleChallenge }
            record.setValue(instant, forKey: "endedAt")
            try save(context)
        }
    }

    /// Set semantics make repeated taps/retries idempotent. Nil restores an unrecorded day.
    func checkIn(
        challengeID: UUID, commitmentID: UUID, on date: Date, status: ChallengeCheckInStatus?
    ) throws {
        try transaction {
            let instant = now()
            guard let record = try records().first(where: { $0.value(forKey: "id") as? UUID == challengeID })
            else { throw ChallengeError.staleChallenge }
            let challenge = try Challenge.decode(record)
            guard let commitment = challenge.commitments.first(where: { $0.id == commitmentID })
            else { throw ChallengeError.staleChallenge }
            let day = challenge.calendar.startOfDay(for: date)
            guard challenge.scheduledDays(for: commitment, through: instant).contains(day)
            else { throw ChallengeError.invalidDay }
            let key = "\(commitmentID.uuidString)/\(Int(day.timeIntervalSince1970))"
            let request = NSFetchRequest<NSManagedObject>(entityName: "ChallengeCheckInRecord")
            request.predicate = NSPredicate(format: "key == %@", key)
            let existing = try context.fetch(request).first
            guard let status else {
                if let existing { context.delete(existing); try save(context) }
                return
            }
            if existing?.value(forKey: "status") as? String == status.rawValue { return }
            let checkIn = existing ?? NSEntityDescription.insertNewObject(
                forEntityName: "ChallengeCheckInRecord", into: context
            )
            if existing == nil {
                let commitments = record.value(forKey: "commitments") as? Set<NSManagedObject> ?? []
                guard let parent = commitments.first(where: { $0.value(forKey: "id") as? UUID == commitmentID })
                else { throw ChallengeError.corruptStore }
                checkIn.setValuesForKeys([
                    "key": key, "day": day, "recordedAt": instant, "commitment": parent
                ])
            }
            checkIn.setValue(status.rawValue, forKey: "status")
            checkIn.setValue(instant, forKey: "updatedAt")
            try save(context)
        }
    }

    private func records() throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ChallengeRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try context.fetch(request)
    }

    private func insert(_ draft: CommitmentDraft, position: Int, into challenge: NSManagedObject) {
        let record = NSEntityDescription.insertNewObject(forEntityName: "CommitmentRecord", into: context)
        let mask = draft.weekdays.reduce(0) { $0 | (1 << ($1 - 1)) }
        record.setValuesForKeys([
            "id": UUID(), "title": draft.title, "category": draft.category,
            "weekdays": mask, "position": position, "challenge": challenge
        ])
        record.setValue(draft.cue, forKey: "cue")
        record.setValue(draft.smallStart, forKey: "smallStart")
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        context.reset()
        do { return try operation() } catch {
            context.rollback()
            throw error
        }
    }
}
