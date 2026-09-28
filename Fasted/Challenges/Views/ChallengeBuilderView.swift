import SwiftUI

/// Category-led manual challenge builder.
struct ChallengeBuilderView: View {
    @ObservedObject var challengeManager: ChallengeManager
    @Environment(\.dismiss) private var dismiss

    @State private var challengeTitle: String = "24-Day Reset"
    @State private var challengeReason: String = ""
    @State private var selectedDuration: Int = 24
    @State private var isCustomDuration: Bool = false
    @State private var customDuration: Int = 24
    @State private var commitments: [CommitmentDraft] = [
        CommitmentDraft(
            title: "Daily 20-minute walk",
            category: "movement",
            cue: "After lunch",
            smallStart: "Put on walking shoes",
            weekdays: Set(1...7)
        )
    ]
    @State private var selectedCategory: String = "movement"
    @State private var showReplaceConfirmation: Bool = false
    @State private var errorMessage: String?

    init(challengeManager: ChallengeManager) {
        self.challengeManager = challengeManager
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                durationSection
                commitmentsSection
                addCommitmentSection

                if challengeManager.activeChallenge != nil {
                    replaceNoticeSection
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("builder_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        handleStartTapped()
                    }
                    .font(.headline)
                    .accessibilityIdentifier("builder_start_button")
                }
            }
            .alert("Couldn't Start Challenge", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "Replace Active Challenge?",
                isPresented: $showReplaceConfirmation,
                titleVisibility: .visible
            ) {
                Button("Archive Current & Start", role: .destructive) {
                    executeStart(replacing: challengeManager.activeChallenge?.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let title = challengeManager.activeChallenge?.title ?? "current challenge"
                Text("Starting a new challenge will archive '\(title)'. Your past progress is safely preserved.")
            }
        }
    }

    private var detailsSection: some View {
        Section("Challenge Details") {
            TextField("Challenge Title", text: $challengeTitle)
                .accessibilityIdentifier("builder_challenge_title_field")

            TextField("Why are you doing this? (Optional)", text: $challengeReason)
                .accessibilityIdentifier("builder_challenge_reason_field")
        }
    }

    private var durationSection: some View {
        Section("Duration") {
            Picker("Length", selection: Binding(
                get: { isCustomDuration ? -1 : selectedDuration },
                set: { val in
                    if val == -1 {
                        isCustomDuration = true
                    } else {
                        isCustomDuration = false
                        selectedDuration = val
                    }
                }
            )) {
                Text("24 Days").tag(24)
                Text("30 Days").tag(30)
                Text("75 Days").tag(75)
                Text("Custom").tag(-1)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("builder_duration_picker")

            if isCustomDuration {
                Stepper(
                    "\(customDuration) days",
                    value: $customDuration,
                    in: 7...90
                )
                .accessibilityIdentifier("builder_custom_duration_stepper")
            }
        }
    }

    private var commitmentsSection: some View {
        Section("Commitments (\(commitments.count) of 6)") {
            ForEach(commitments.indices, id: \.self) { idx in
                CommitmentDraftRow(
                    index: idx,
                    canDelete: commitments.count > 1,
                    commitment: $commitments[idx],
                    onDelete: {
                        commitments.remove(at: idx)
                    }
                )
            }
        }
    }

    private var addCommitmentSection: some View {
        Section("Add a Commitment") {
            if commitments.count < 6 {
                categoryPickerView
                suggestionsView

                Button {
                    addBlankCommitment()
                } label: {
                    Label("Add Custom Commitment", systemImage: "plus")
                }
                .accessibilityIdentifier("builder_add_custom_button")
            } else {
                Text("Maximum of 6 commitments reached.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var categoryPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChallengeTemplates.categories) { cat in
                    Button {
                        selectedCategory = cat.id
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                            Text(cat.name)
                        }
                        .font(.caption.weight(selectedCategory == cat.id ? .bold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedCategory == cat.id ?
                            Color.accentColor.opacity(0.2) : Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("builder_category_\(cat.id)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var suggestionsView: some View {
        Group {
            if let items = ChallengeTemplates.suggestions[selectedCategory] {
                ForEach(items) { item in
                    Button {
                        addSuggestedCommitment(item, category: selectedCategory)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("Cue: \(item.cue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .accessibilityIdentifier("builder_suggestion_\(item.title)")
                }
            }
        }
    }

    private var replaceNoticeSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(SolsticeColors.solarAmber)
                Text("Starting this challenge will archive your current active challenge without losing any past data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addSuggestedCommitment(_ suggestion: ChallengeSuggestionItem, category: String) {
        guard commitments.count < 6 else { return }
        let draft = CommitmentDraft(
            title: suggestion.title,
            category: category,
            cue: suggestion.cue,
            smallStart: suggestion.smallStart,
            weekdays: Set(1...7)
        )
        commitments.append(draft)
    }

    private func addBlankCommitment() {
        guard commitments.count < 6 else { return }
        let draft = CommitmentDraft(
            title: "",
            category: selectedCategory,
            cue: nil,
            smallStart: nil,
            weekdays: Set(1...7)
        )
        commitments.append(draft)
    }

    private func handleStartTapped() {
        if challengeManager.activeChallenge != nil {
            showReplaceConfirmation = true
        } else {
            executeStart()
        }
    }

    private func executeStart(replacing: UUID? = nil) {
        let days = isCustomDuration ? customDuration : selectedDuration
        let draft = ChallengeDraft(
            title: challengeTitle,
            reason: challengeReason.isEmpty ? nil : challengeReason,
            dayCount: days,
            commitments: commitments
        )

        do {
            try challengeManager.startChallenge(draft: draft, replacing: replacing)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommitmentDraftRow: View {
    let index: Int
    let canDelete: Bool
    @Binding var commitment: CommitmentDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: categoryIcon(for: commitment.category))
                    .foregroundStyle(SolsticeColors.solarAmber)

                TextField("Commitment title", text: $commitment.title)
                    .accessibilityIdentifier("builder_commitment_title_\(index)")

                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("builder_delete_commitment_\(index)")
                }
            }

            TextField("Habit anchor / Cue (optional, e.g. 'After lunch')", text: Binding(
                get: { commitment.cue ?? "" },
                set: { commitment.cue = $0.isEmpty ? nil : $0 }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("builder_commitment_cue_\(index)")

            TextField("Starter step (optional, e.g. 'Put on shoes')", text: Binding(
                get: { commitment.smallStart ?? "" },
                set: { commitment.smallStart = $0.isEmpty ? nil : $0 }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("builder_commitment_start_\(index)")

            weekdayPicker
        }
        .padding(.vertical, 4)
    }

    private var weekdayPicker: some View {
        let isDaily = commitment.weekdays == Set(1...7)
        let isWeekdays = commitment.weekdays == Set(2...6)

        return HStack(spacing: 6) {
            Button {
                commitment.weekdays = Set(1...7)
            } label: {
                Text("Daily")
                    .font(.caption2.weight(isDaily ? .bold : .regular))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isDaily ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                commitment.weekdays = Set(2...6)
            } label: {
                Text("Mon-Fri")
                    .font(.caption2.weight(isWeekdays ? .bold : .regular))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isWeekdays ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func categoryIcon(for cat: String) -> String {
        ChallengeTemplates.categories.first { $0.id == cat }?.icon ?? "checklist"
    }
}
