import SwiftUI

@main
struct FastedWatchApp: App {
    init() {
        WatchSessionCoordinator.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
