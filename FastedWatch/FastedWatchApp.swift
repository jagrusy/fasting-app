import SwiftUI

@main
struct FastedWatchApp: App {
    init() {
        WatchSessionCoordinator.shared.activate()
        seedMockDataIfNeeded()
    }

    private func seedMockDataIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        let duration: TimeInterval = 16 * 3600
        if args.contains("-seedScreenshots80") {
            let start = Date().addingTimeInterval(-0.80 * duration)
            WatchSessionCoordinator.shared.snapshot = FastingStateSnapshot(
                isFasting: true,
                startDate: start,
                targetDuration: duration,
                protocolType: "16:8",
                currentStreak: 14,
                longestStreak: 14,
                lastCompletedFastDate: Date().addingTimeInterval(-24 * 3600),
                updatedAt: Date()
            )
        } else if args.contains("-seedScreenshots100") {
            let start = Date().addingTimeInterval(-1.05 * duration)
            WatchSessionCoordinator.shared.snapshot = FastingStateSnapshot(
                isFasting: true,
                startDate: start,
                targetDuration: duration,
                protocolType: "16:8",
                currentStreak: 14,
                longestStreak: 14,
                lastCompletedFastDate: Date().addingTimeInterval(-24 * 3600),
                updatedAt: Date()
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
