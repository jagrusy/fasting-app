import Foundation

/// A proposed challenge program, independent of how it was produced (the on-device model today,
/// templates later), so the review UI and tests never depend on FoundationModels.
public struct ProgramProposal: Equatable {
    public struct Habit: Equatable {
        public var name: String
        public var symbol: String
        public var cadence: Cadence

        public init(name: String, symbol: String, cadence: Cadence) {
            self.name = name
            self.symbol = symbol
            self.cadence = cadence
        }
    }

    public enum Cadence: Equatable {
        case daily
        case weekdays
        case timesPerWeek(Int)

        public var label: String {
            switch self {
            case .daily: return "Daily"
            case .weekdays: return "Weekdays"
            case .timesPerWeek(let count): return "\(count)× a week"
            }
        }

        /// Lenient parse of model output such as "daily", "weekdays" or "3 times per week".
        public static func parse(_ text: String) -> Cadence {
            let lowered = text.lowercased()
            if lowered.contains("weekday") {
                return .weekdays
            }
            if lowered.contains("week"),
               let count = lowered.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) }).first {
                return .timesPerWeek(count)
            }
            return .daily
        }
    }

    public var title: String
    public var lengthDays: Int
    public var habits: [Habit]
    public var fastingNote: String?

    public init(title: String, lengthDays: Int, habits: [Habit], fastingNote: String? = nil) {
        self.title = title
        self.lengthDays = lengthDays
        self.habits = habits
        self.fastingNote = fastingNote
    }

    public static let lengthRange = 7...90
    public static let maxHabits = 6
    public static let maxTitleLength = 40
    public static let defaultTitle = "My Challenge"
    public static let defaultSymbol = "checkmark.circle"

    /// SF Symbols a habit may use. Model output outside this list falls back to `defaultSymbol`,
    /// so a hallucinated name can never render as a blank image.
    public static let allowedSymbols: [String] = [
        "checkmark.circle", "pills", "drop", "snowflake", "figure.run", "figure.walk",
        "dumbbell", "bed.double", "moon.zzz", "leaf", "fork.knife", "cup.and.saucer",
        "book", "brain.head.profile", "sun.max", "heart"
    ]

    /// Clamps and cleans a proposal so anything shown or saved is within the app's limits,
    /// whatever the model returned.
    public func sanitized() -> ProgramProposal {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = trimmedTitle.isEmpty ? Self.defaultTitle : String(trimmedTitle.prefix(Self.maxTitleLength))

        var seen = Set<String>()
        var cleanHabits: [Habit] = []
        for habit in habits {
            let name = habit.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            let symbol = Self.allowedSymbols.contains(habit.symbol) ? habit.symbol : Self.defaultSymbol
            cleanHabits.append(Habit(name: name, symbol: symbol, cadence: Self.clamped(habit.cadence)))
            if cleanHabits.count == Self.maxHabits { break }
        }

        let note = fastingNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProgramProposal(
            title: cleanTitle,
            lengthDays: min(max(lengthDays, Self.lengthRange.lowerBound), Self.lengthRange.upperBound),
            habits: cleanHabits,
            fastingNote: (note?.isEmpty ?? true) ? nil : note
        )
    }

    private static func clamped(_ cadence: Cadence) -> Cadence {
        guard case .timesPerWeek(let count) = cadence else { return cadence }
        if count >= 7 { return .daily }
        return .timesPerWeek(max(1, count))
    }
}

/// Turns free-text goals into a proposed program. Injected so tests and devices without Apple
/// Intelligence never touch FoundationModels.
public protocol ProgramSuggesting {
    func suggestProgram(for goals: String) async throws -> ProgramProposal
}
