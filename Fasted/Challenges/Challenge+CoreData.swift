import CoreData

extension Challenge {
    static func decode(_ record: NSManagedObject) throws -> Challenge {
        guard let id = record.value(forKey: "id") as? UUID,
              let title = record.value(forKey: "title") as? String,
              let start = record.value(forKey: "startDate") as? Date,
              let count = record.value(forKey: "dayCount") as? Int,
              let zone = record.value(forKey: "timeZoneID") as? String,
              let created = record.value(forKey: "createdAt") as? Date,
              TimeZone(identifier: zone) != nil, (7...90).contains(count)
        else { throw ChallengeError.corruptStore }
        let records = (record.value(forKey: "commitments") as? Set<NSManagedObject> ?? []).sorted {
            ($0.value(forKey: "position") as? Int ?? 0) < ($1.value(forKey: "position") as? Int ?? 0)
        }
        let commitments = try records.map(decodeCommitment)
        _ = try ChallengeDraft(title: title, dayCount: count, timeZoneID: zone,
                               commitments: commitments.map(\.draft)).validated()
        let checkIns = try records.flatMap { commitment in
            let rows = commitment.value(forKey: "checkIns") as? Set<NSManagedObject> ?? []
            return try rows.map { try decodeCheckIn($0, commitment: commitment) }
        }
        return Challenge(
            id: id, title: title, reason: record.value(forKey: "reason") as? String,
            startDate: start, dayCount: count, timeZoneID: zone, createdAt: created,
            endedAt: record.value(forKey: "endedAt") as? Date, commitments: commitments, checkIns: checkIns
        )
    }

    private static func decodeCommitment(_ record: NSManagedObject) throws -> ChallengeCommitment {
        guard let id = record.value(forKey: "id") as? UUID,
              let title = record.value(forKey: "title") as? String,
              let category = record.value(forKey: "category") as? String,
              let mask = record.value(forKey: "weekdays") as? Int, (1...127).contains(mask)
        else { throw ChallengeError.corruptStore }
        let weekdays = Set((1...7).filter { mask & (1 << ($0 - 1)) != 0 })
        return ChallengeCommitment(id: id, draft: CommitmentDraft(
            title: title, category: category, cue: record.value(forKey: "cue") as? String,
            smallStart: record.value(forKey: "smallStart") as? String, weekdays: weekdays
        ))
    }

    private static func decodeCheckIn(
        _ record: NSManagedObject, commitment: NSManagedObject
    ) throws -> ChallengeCheckIn {
        guard let id = commitment.value(forKey: "id") as? UUID,
              let day = record.value(forKey: "day") as? Date,
              let rawStatus = record.value(forKey: "status") as? String,
              let status = ChallengeCheckInStatus(rawValue: rawStatus),
              let recorded = record.value(forKey: "recordedAt") as? Date,
              let updated = record.value(forKey: "updatedAt") as? Date
        else { throw ChallengeError.corruptStore }
        return ChallengeCheckIn(commitmentID: id, day: day, status: status, recordedAt: recorded, updatedAt: updated)
    }
}
