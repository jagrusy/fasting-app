import Foundation
import CoreData
import StoreKit

@MainActor
public final class ReviewPromptManager {
    public static let shared = ReviewPromptManager()

    private let userDefaults: UserDefaults
    private let calendar: Calendar

    public static let lastPromptDateKey = "solstice_last_review_prompt_date"
    public static let lastPromptVersionKey = "solstice_last_review_prompt_version"

    public init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    public func isEligibleForReviewPrompt(
        completedFast: Fast,
        allCompletedFasts: [Fast],
        currentDate: Date = Date()
    ) -> Bool {
        guard completedFast.isCompleted else { return false }

        let completedCount = allCompletedFasts.filter { $0.isCompleted }.count
        let streak = StreakCalculator.calculate(from: allCompletedFasts).currentStreak

        // Milestone triggers: 3rd fast, 7-day streak, 7th fast, 14th fast
        let isMilestone = (completedCount == 3) || (streak == 7) || (completedCount == 7) || (completedCount == 14)
        guard isMilestone else { return false }

        // Cooldown check: at least 60 days between automatic prompts
        if let lastDate = userDefaults.object(forKey: Self.lastPromptDateKey) as? Date {
            let daysSince = calendar.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0
            if daysSince < 60 {
                return false
            }
        }

        return true
    }

    public func checkAndPromptIfEligible(
        completedFast: Fast,
        allCompletedFasts: [Fast],
        currentDate: Date = Date()
    ) {
        guard isEligibleForReviewPrompt(
            completedFast: completedFast,
            allCompletedFasts: allCompletedFasts,
            currentDate: currentDate
        ) else {
            return
        }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.userDefaults.set(currentDate, forKey: Self.lastPromptDateKey)
        self.userDefaults.set(currentVersion, forKey: Self.lastPromptVersionKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            FeedbackHelper.requestAppStoreReview()
        }
    }
}
