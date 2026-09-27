#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GeneratedProgram {
    @Guide(description: "A short, motivating name for the challenge, at most four words")
    var title: String

    @Guide(description: "Length of the challenge in days, between 7 and 90. Use 30 unless the goals say otherwise.")
    var lengthDays: Int

    @Guide(description: "Between one and six simple, checkable daily habits taken from the goals")
    var habits: [GeneratedHabit]

    @Guide(description: "One short sentence about the fasting schedule mentioned in the goals, or empty if none")
    var fastingNote: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedHabit {
    @Guide(description: "Habit name of one to four words, for example Cold plunge")
    var name: String

    @Guide(description: """
        An SF Symbol name, exactly one of: checkmark.circle, pills, drop, snowflake, figure.run, \
        figure.walk, dumbbell, bed.double, moon.zzz, leaf, fork.knife, cup.and.saucer, book, \
        brain.head.profile, sun.max, heart
        """)
    var symbol: String

    @Guide(description: "How often: daily, weekdays, or a number of times per week such as 3 times per week")
    var cadence: String
}

/// Proposes a program with Apple's on-device model. Nothing leaves the device.
@available(iOS 26.0, *)
struct FoundationModelsProgramSuggester: ProgramSuggesting {
    static let instructions = """
        You help someone set up a personal wellness challenge. From their goals, propose a short \
        program: a title, a length in days, and a few simple daily habits they can check off. \
        Only include habits the person mentioned or clearly implied. Do not give medical advice, \
        calorie targets or diets.
        """

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static var availabilityDescription: String {
        isAvailable ? "Available" : "Unavailable: \(SystemLanguageModel.default.availability)"
    }

    func suggestProgram(for goals: String) async throws -> ProgramProposal {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: goals, generating: GeneratedProgram.self)
        let generated = response.content
        return ProgramProposal(
            title: generated.title,
            lengthDays: generated.lengthDays,
            habits: generated.habits.map {
                ProgramProposal.Habit(
                    name: $0.name,
                    symbol: $0.symbol,
                    cadence: ProgramProposal.Cadence.parse($0.cadence)
                )
            },
            fastingNote: generated.fastingNote
        ).sanitized()
    }
}
#endif
