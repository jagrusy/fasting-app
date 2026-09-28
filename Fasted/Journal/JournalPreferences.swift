import Foundation

/// Durable local preferences for optional food journal visibility and post-fast prompts.
@MainActor
public final class JournalPreferences: ObservableObject {
    public static let shared = JournalPreferences()
    private let userDefaults: UserDefaults

    private let journalEnabledKey = "Fasted.isJournalEnabled"
    private let postFastPromptKey = "Fasted.postFastPromptEnabled"
    private let permanentOptOutKey = "Fasted.hasDeclinedPostFastPromptPermanently"

    @Published public var isJournalEnabled: Bool {
        didSet {
            userDefaults.set(isJournalEnabled, forKey: journalEnabledKey)
        }
    }

    @Published public var postFastPromptEnabled: Bool {
        didSet {
            userDefaults.set(postFastPromptEnabled, forKey: postFastPromptKey)
        }
    }

    @Published public var hasDeclinedPostFastPromptPermanently: Bool {
        didSet {
            userDefaults.set(hasDeclinedPostFastPromptPermanently, forKey: permanentOptOutKey)
        }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isJournalEnabled = userDefaults.bool(forKey: journalEnabledKey)
        self.postFastPromptEnabled = userDefaults.bool(forKey: postFastPromptKey)
        self.hasDeclinedPostFastPromptPermanently = userDefaults.bool(forKey: permanentOptOutKey)
    }

    public static func resolveDefault() -> JournalPreferences {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else {
            return .shared
        }
        let identifier = ProcessInfo.processInfo.environment["UITEST_STORE_ID"] ?? UUID().uuidString
        let suite = UserDefaults(suiteName: "uitest_\(identifier)") ?? .standard
        let prefs = JournalPreferences(userDefaults: suite)
        if ProcessInfo.processInfo.arguments.contains("-enableJournal") {
            prefs.isJournalEnabled = true
        }
        if ProcessInfo.processInfo.arguments.contains("-enablePostFastPrompt") {
            prefs.postFastPromptEnabled = true
        }
        return prefs
    }
}
