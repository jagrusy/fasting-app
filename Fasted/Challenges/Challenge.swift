import Foundation

enum ChallengeError: LocalizedError {
    case invalidDraft, alreadyActive, staleChallenge, invalidDay, corruptStore

    var errorDescription: String? {
        switch self {
        case .invalidDraft: return "Choose a title, 7–90 days, and 1–6 different commitments with scheduled days."
        case .alreadyActive: return "Review your current challenge before starting a new one."
        case .staleChallenge: return "Your challenge changed. Refresh it and try again."
        case .invalidDay: return "Choose a scheduled challenge day that has already started."
        case .corruptStore: return "Solstice couldn't read this challenge. Your saved data has been kept."
        }
    }
}

struct CommitmentDraft: Equatable {
    var title: String
    var category = "personal"
    var cue: String?
    var smallStart: String?
    /// Gregorian weekdays: Sunday = 1, Saturday = 7. Empty is never daily.
    var weekdays = Set(1...7)
}

struct ChallengeDraft {
    var title: String
    var reason: String?
    var dayCount = 24
    var timeZoneID = TimeZone.current.identifier
    var commitments: [CommitmentDraft]

    func validated() throws -> Self {
        var draft = self
        draft.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.commitments = commitments.map { commitment in
            var clean = commitment
            clean.title = commitment.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean
        }
        let titles = draft.commitments.map { $0.title.lowercased() }
        guard !draft.title.isEmpty, (7...90).contains(dayCount), TimeZone(identifier: timeZoneID) != nil,
              (1...6).contains(commitments.count), Set(titles).count == titles.count,
              draft.commitments.allSatisfy({
                  !$0.title.isEmpty && !$0.weekdays.isEmpty && $0.weekdays.isSubset(of: Set(1...7))
              }) else { throw ChallengeError.invalidDraft }
        return draft
    }
}

enum ChallengeCheckInStatus: String {
    case done, notDone
    // No row represents unrecorded; an unscheduled day never gets a row.
}

struct ChallengeCommitment: Identifiable, Equatable {
    let id: UUID
    let draft: CommitmentDraft
}

struct ChallengeCheckIn: Equatable {
    let commitmentID: UUID
    let day: Date
    let status: ChallengeCheckInStatus
    let recordedAt: Date
    let updatedAt: Date
}

struct Challenge: Identifiable {
    let id: UUID
    let title: String
    let reason: String?
    let startDate: Date
    let dayCount: Int
    let timeZoneID: String
    let createdAt: Date
    let endedAt: Date?
    let commitments: [ChallengeCommitment]
    let checkIns: [ChallengeCheckIn]

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return calendar
    }

    /// Exclusive boundary; calendar arithmetic preserves local midnight through DST.
    var endDate: Date { calendar.date(byAdding: .day, value: dayCount, to: startDate) ?? startDate }

    func isActive(at now: Date) -> Bool { endedAt == nil && now >= startDate && now < endDate }

    func scheduledDays(for commitment: ChallengeCommitment, through now: Date) -> [Date] {
        let lastDay = calendar.startOfDay(for: min(now, endedAt ?? now))
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDate), day <= lastDay,
                  commitment.draft.weekdays.contains(calendar.component(.weekday, from: day)) else { return nil }
            return day
        }
    }

    func completedCount(for commitment: ChallengeCommitment, through now: Date) -> Int {
        let scheduled = Set(scheduledDays(for: commitment, through: now))
        return checkIns.filter {
            $0.commitmentID == commitment.id && $0.status == .done && scheduled.contains($0.day)
        }.count
    }

    func formattedDate(_ date: Date, dateStyle: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .none
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
}
