import Foundation

struct ChallengeCategoryItem: Identifiable {
    let id: String
    let name: String
    let icon: String
}

struct ChallengeSuggestionItem: Identifiable {
    var id: String { title }
    let title: String
    let cue: String
    let smallStart: String
}

enum ChallengeTemplates {
    static let categories: [ChallengeCategoryItem] = [
        ChallengeCategoryItem(id: "movement", name: "Movement", icon: "figure.run"),
        ChallengeCategoryItem(id: "sleep", name: "Sleep", icon: "moon.stars.fill"),
        ChallengeCategoryItem(id: "food", name: "Food", icon: "leaf.fill"),
        ChallengeCategoryItem(id: "mindfulness", name: "Mindfulness", icon: "sparkles"),
        ChallengeCategoryItem(id: "routine", name: "Routine", icon: "checklist"),
        ChallengeCategoryItem(id: "custom", name: "Custom", icon: "pencil")
    ]

    static let suggestions: [String: [ChallengeSuggestionItem]] = [
        "movement": [
            ChallengeSuggestionItem(
                title: "Daily 20-minute walk",
                cue: "After lunch",
                smallStart: "Put on walking shoes"
            ),
            ChallengeSuggestionItem(
                title: "Morning stretch & mobility",
                cue: "After getting out of bed",
                smallStart: "Unroll mat"
            ),
            ChallengeSuggestionItem(
                title: "Strength workout",
                cue: "Before dinner",
                smallStart: "Change into workout clothes"
            )
        ],
        "sleep": [
            ChallengeSuggestionItem(
                title: "Screens off 30 min before bed",
                cue: "When winding down",
                smallStart: "Plug phone across room"
            ),
            ChallengeSuggestionItem(
                title: "In bed by 10:30 PM",
                cue: "After evening routine",
                smallStart: "Dim the lights"
            ),
            ChallengeSuggestionItem(
                title: "No caffeine after 2 PM",
                cue: "After lunch",
                smallStart: "Switch to water or herbal tea"
            )
        ],
        "food": [
            ChallengeSuggestionItem(
                title: "Photograph eating occasions",
                cue: "Before first bite",
                smallStart: "Take phone out"
            ),
            ChallengeSuggestionItem(
                title: "No eating after dinner",
                cue: "After clearing dishes",
                smallStart: "Brush teeth early"
            ),
            ChallengeSuggestionItem(
                title: "Drink water before meals",
                cue: "Before sitting to eat",
                smallStart: "Pour a glass of water"
            )
        ],
        "mindfulness": [
            ChallengeSuggestionItem(
                title: "5-minute breathing pause",
                cue: "After morning coffee",
                smallStart: "Sit comfortably"
            ),
            ChallengeSuggestionItem(
                title: "Evening gratitude reflection",
                cue: "Before turning off light",
                smallStart: "Think of one good moment"
            ),
            ChallengeSuggestionItem(
                title: "Mindful first 3 bites",
                cue: "When beginning a meal",
                smallStart: "Pause without screens"
            )
        ],
        "routine": [
            ChallengeSuggestionItem(
                title: "Take daily vitamins",
                cue: "With morning meal",
                smallStart: "Place bottle by water"
            ),
            ChallengeSuggestionItem(
                title: "Read 10 pages",
                cue: "Before bed",
                smallStart: "Open book to bookmark"
            ),
            ChallengeSuggestionItem(
                title: "Evening kitchen reset",
                cue: "After dinner",
                smallStart: "Clear the counter"
            )
        ]
    ]
}
