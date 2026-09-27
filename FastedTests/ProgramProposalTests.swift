import XCTest
@testable import Fasted

/// `sanitized()` is the only thing standing between raw model output and what the app shows or
/// saves, so it must hold every limit regardless of what the model returns.
final class ProgramProposalTests: XCTestCase {
    private func habit(_ name: String, symbol: String = "pills", cadence: ProgramProposal.Cadence = .daily)
        -> ProgramProposal.Habit {
        ProgramProposal.Habit(name: name, symbol: symbol, cadence: cadence)
    }

    func testLengthIsClampedToTheAllowedRange() {
        XCTAssertEqual(ProgramProposal(title: "A", lengthDays: 3, habits: []).sanitized().lengthDays, 7)
        XCTAssertEqual(ProgramProposal(title: "A", lengthDays: 365, habits: []).sanitized().lengthDays, 90)
        XCTAssertEqual(ProgramProposal(title: "A", lengthDays: 30, habits: []).sanitized().lengthDays, 30)
    }

    func testBlankTitleFallsBackAndLongTitleIsTruncated() {
        XCTAssertEqual(ProgramProposal(title: "   ", lengthDays: 30, habits: []).sanitized().title, "My Challenge")
        let long = String(repeating: "x", count: 100)
        XCTAssertEqual(ProgramProposal(title: long, lengthDays: 30, habits: []).sanitized().title.count, 40)
    }

    func testHabitsAreTrimmedDeduplicatedAndCapped() {
        let habits = [
            habit(" Supplements "), habit("supplements"), habit(""), habit("Cold plunge"),
            habit("Walk"), habit("Read"), habit("Journal"), habit("Stretch"), habit("Sleep by 11")
        ]
        let result = ProgramProposal(title: "Reset", lengthDays: 30, habits: habits).sanitized()

        XCTAssertEqual(result.habits.map(\.name), ["Supplements", "Cold plunge", "Walk", "Read", "Journal", "Stretch"])
        XCTAssertEqual(result.habits.count, ProgramProposal.maxHabits)
    }

    func testUnknownSymbolsFallBackToTheDefault() {
        let result = ProgramProposal(
            title: "Reset",
            lengthDays: 30,
            habits: [habit("Plunge", symbol: "snowflake"), habit("Made up", symbol: "not.a.real.symbol")]
        ).sanitized()

        XCTAssertEqual(result.habits.map(\.symbol), ["snowflake", ProgramProposal.defaultSymbol])
    }

    func testTimesPerWeekIsClamped() {
        let result = ProgramProposal(
            title: "Reset",
            lengthDays: 30,
            habits: [habit("A", cadence: .timesPerWeek(0)), habit("B", cadence: .timesPerWeek(9))]
        ).sanitized()

        XCTAssertEqual(result.habits.map(\.cadence), [.timesPerWeek(1), .daily])
    }

    func testEmptyFastingNoteBecomesNil() {
        XCTAssertNil(ProgramProposal(title: "A", lengthDays: 30, habits: [], fastingNote: "  ").sanitized().fastingNote)
        let note = ProgramProposal(title: "A", lengthDays: 30, habits: [], fastingNote: " 16:8 on weekdays ")
        XCTAssertEqual(note.sanitized().fastingNote, "16:8 on weekdays")
    }

    func testCadenceParsesLooseModelOutput() {
        XCTAssertEqual(ProgramProposal.Cadence.parse("Daily"), .daily)
        XCTAssertEqual(ProgramProposal.Cadence.parse("weekdays only"), .weekdays)
        XCTAssertEqual(ProgramProposal.Cadence.parse("3 times per week"), .timesPerWeek(3))
        XCTAssertEqual(ProgramProposal.Cadence.parse("twice a week"), .daily)
        XCTAssertEqual(ProgramProposal.Cadence.parse("every morning"), .daily)
    }
}
