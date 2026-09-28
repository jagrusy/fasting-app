import SwiftUI

public struct JournalSettingsSection: View {
    @ObservedObject var mealManager: MealManager

    public init(mealManager: MealManager) {
        self.mealManager = mealManager
    }

    public var body: some View {
        Section {
            Toggle("Enable Food Journal", isOn: $mealManager.isJournalEnabled)
                .accessibilityIdentifier("settings_journal_toggle")

            if mealManager.isJournalEnabled {
                Toggle(
                    "Prompt to log meal after ending a fast",
                    isOn: Binding(
                        get: { mealManager.postFastPromptEnabled && !mealManager.hasDeclinedPostFastPromptPermanently },
                        set: { enabled in
                            mealManager.postFastPromptEnabled = enabled
                            if enabled {
                                mealManager.hasDeclinedPostFastPromptPermanently = false
                            }
                        }
                    )
                )
                .accessibilityIdentifier("settings_post_fast_prompt_toggle")

                if mealManager.hasDeclinedPostFastPromptPermanently {
                    Text(
                        "You previously selected 'Don't ask again'. Turn the toggle on above to re-enable "
                        + "post-fast invitations."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Food Journal")
        } footer: {
            Text("Turning off the journal hides its tabs and prompts, but never deletes your saved meals or photos.")
        }
    }
}
