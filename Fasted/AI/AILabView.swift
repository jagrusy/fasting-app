import SwiftUI

/// Hidden developer screen (Settings → tap Version 7 times) for trying on-device program
/// suggestions and the share-to-AI hand-off on a real device before building the features.
struct AILabView: View {
    @State private var goals = "30-day reset: cut sugar, cold plunge 3 times a week, supplements every "
        + "morning, and 16:8 fasting on weekdays"
    @State private var proposal: ProgramProposal?
    @State private var errorText: String?
    @State private var isGenerating = false
    @State private var elapsed: TimeInterval?

    var body: some View {
        Form {
            Section("Apple Intelligence") {
                Text(availabilityText)
                    .font(.subheadline)
            }

            Section("Goals") {
                TextField("Describe your goals", text: $goals, axis: .vertical)
                    .lineLimit(3...8)
                Button(isGenerating ? "Generating…" : "Generate program") {
                    generate()
                }
                .disabled(isGenerating || !modelAvailable || trimmedGoals.isEmpty)
                if let elapsed = elapsed {
                    Text(String(format: "Took %.1f s", elapsed))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let proposal = proposal {
                proposalSection(proposal)
            }

            if let errorText = errorText {
                Section("Error") {
                    Text(errorText)
                        .font(.caption.monospaced())
                }
            }

            shareSection
        }
        .navigationTitle("AI Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func proposalSection(_ proposal: ProgramProposal) -> some View {
        Section {
            ForEach(Array(proposal.habits.enumerated()), id: \.offset) { _, habit in
                Label {
                    VStack(alignment: .leading) {
                        Text(habit.name)
                        Text(habit.cadence.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: habit.symbol)
                }
            }
            if let note = proposal.fastingNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("\(proposal.title) · \(proposal.lengthDays) days")
        }
    }

    private var shareSection: some View {
        Section {
            ShareLink(item: ShareTestPrompt.sample) {
                Label("Share sample meal prompt", systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.string = ShareTestPrompt.sample
            } label: {
                Label("Copy sample prompt", systemImage: "doc.on.doc")
            }
        } header: {
            Text("Share to AI apps")
        } footer: {
            Text("Share to ChatGPT, Claude and Gemini and note whether each opens a new chat with the text.")
        }
    }

    private var trimmedGoals: String {
        goals.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsProgramSuggester.isAvailable
        }
        #endif
        return false
    }

    private var availabilityText: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsProgramSuggester.availabilityDescription
        }
        #endif
        return "Requires iOS 26 on a device with Apple Intelligence"
    }

    private func generate() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return }
        isGenerating = true
        errorText = nil
        let started = Date()
        let prompt = trimmedGoals
        Task {
            do {
                proposal = try await FoundationModelsProgramSuggester().suggestProgram(for: prompt)
            } catch {
                proposal = nil
                errorText = String(describing: error)
            }
            elapsed = Date().timeIntervalSince(started)
            isGenerating = false
        }
        #endif
    }
}

/// A realistic sample of what the meal-log export will send, used to test how each AI app
/// receives shared text. Contains no real user data.
enum ShareTestPrompt {
    static let sample = """
        Here is my meal and fasting log for the last 3 days. Please look for patterns and give a \
        rough estimate of whether I'm over- or under-eating. No need for exact calories.

        Mon: fasted 16h (20:00–12:00). 12:30 chicken salad, sparkling water. 16:00 apple, almonds. \
        19:00 salmon, rice, broccoli.
        Tue: fasted 18h. 14:00 burrito bowl. 19:30 pasta with meat sauce, 1 glass of wine.
        Wed: fasted 16h. 12:15 eggs and toast. 15:00 protein shake. 19:00 steak, potatoes, salad, \
        2 cookies.
        """
}
