import Foundation

/// Durable local preferences for optional challenges feature visibility.
@MainActor
final class ChallengePreferences: ObservableObject {
    static let shared = ChallengePreferences()
    private let userDefaults: UserDefaults
    private let key = "Fasted.isChallengesEnabled"

    @Published var isChallengesEnabled: Bool {
        didSet {
            userDefaults.set(isChallengesEnabled, forKey: key)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isChallengesEnabled = userDefaults.bool(forKey: key)
    }

    static func resolveDefault() -> ChallengePreferences {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else {
            return .shared
        }
        let identifier = ProcessInfo.processInfo.environment["UITEST_STORE_ID"] ?? UUID().uuidString
        let suite = UserDefaults(suiteName: "uitest_\(identifier)") ?? .standard
        let prefs = ChallengePreferences(userDefaults: suite)
        if ProcessInfo.processInfo.arguments.contains("-enableChallenges") {
            prefs.isChallengesEnabled = true
        }
        return prefs
    }
}
