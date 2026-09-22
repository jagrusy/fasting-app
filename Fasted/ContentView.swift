import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var fastManager: FastManager
    @State private var selectedTab: Tab = .fast
    private let viewContext: NSManagedObjectContext

    /// `FastedApp` also sets `\.managedObjectContext` on its `WindowGroup`, unconditionally pointed
    /// at `PersistenceController.shared` — independent of whatever context this initializer
    /// resolves. Every `@FetchRequest` in this app's descendant views (`HistoryListView` among
    /// them) reads through *that* environment value, not through `fastManager`. Without
    /// re-asserting it here, a `-uiTesting` launch would still write fasts through the isolated
    /// store while every fetch-request view kept reading `.shared` — two disconnected stores
    /// silently coexisting behind what looks like a single injected context.
    init(context: NSManagedObjectContext = ContentView.resolveDefaultContext()) {
        self.viewContext = context
        _fastManager = StateObject(wrappedValue: FastManager(context: context))
    }

    /// Isolates UI test runs onto their own on-disk store instead of the app's real one.
    ///
    /// `PersistenceController.shared` is the single production store every ordinary launch reads
    /// and writes. Without this seam, a UI test run and a developer's own local usage — or a
    /// screenshot-seeding run — share that exact database, which is also how `-seedScreenshots80`
    /// used to reach and erase real fast history (see `FastManager+Mocking.swift`).
    private static func resolveDefaultContext() -> NSManagedObjectContext {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else {
            return PersistenceController.shared.container.viewContext
        }
        let identifier = ProcessInfo.processInfo.environment["UITEST_STORE_ID"] ?? UUID().uuidString
        return PersistenceController.uiTesting(storeIdentifier: identifier).container.viewContext
    }

    enum Tab: String, CaseIterable, Identifiable {
        case fast = "Fast"
        case history = "History"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .fast: return "timer"
            case .history: return "chart.bar"
            case .settings: return "gearshape"
            }
        }

        init?(deepLink: DeepLink) {
            switch deepLink {
            case .fastTracker: self = .fast
            case .history: self = .history
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FastTabView(fastManager: fastManager)
                .tabItem {
                    Label(Tab.fast.rawValue, systemImage: Tab.fast.icon)
                }
                .tag(Tab.fast)

            HistoryTabView(fastManager: fastManager)
                .tabItem {
                    Label(Tab.history.rawValue, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)

            SettingsTabView(fastManager: fastManager)
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .environment(\.managedObjectContext, viewContext)
        .alert(
            "Couldn't Complete That",
            isPresented: Binding(
                get: { fastManager.operationError != nil },
                set: { if !$0 { fastManager.clearOperationError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                fastManager.clearOperationError()
            }
        } message: {
            Text(fastManager.operationError?.message ?? "Your saved fasting data is unchanged. Please try again.")
        }
        .preferredColorScheme(
            ProcessInfo.processInfo.arguments.contains("-forceDarkMode") ? .dark :
            ProcessInfo.processInfo.arguments.contains("-forceLightMode") ? .light : nil
        )
        .onAppear {
            #if DEBUG
            // Compiled out of Release entirely — not just runtime-gated — so no launch argument
            // can reach `clearAllFastingData()` in a shipped build. `-uiTesting` is required
            // alongside the seed flag so this can only ever run against the isolated store from
            // `resolveDefaultContext()`, never a developer's real local database.
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                if ProcessInfo.processInfo.arguments.contains("-seedScreenshots80") {
                    fastManager.seedMockDataForScreenshots(progress: 0.80)
                } else if ProcessInfo.processInfo.arguments.contains("-seedScreenshots100") {
                    fastManager.seedMockDataForScreenshots(progress: 1.05)
                }
            }
            #endif
            fastManager.refresh()
            fastManager.syncNotifications()
            applyPendingDeepLink()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // The primary drain trigger: applies anything the widget, Control Center, or the
                // watch enqueued while the app was backgrounded or terminated.
                fastManager.refresh()
                fastManager.syncNotifications()
                applyPendingDeepLink()
            }
        }
        .onOpenURL { url in
            if let link = DeepLink(url: url), let tab = Tab(deepLink: link) {
                selectedTab = tab
            }
        }
    }

    /// Picks up a tab switch a Control Center intent requested while the app wasn't in the
    /// foreground to receive a `widgetURL`-style open directly.
    private func applyPendingDeepLink() {
        if let link = fastManager.coordinator.consumePendingDeepLink(), let tab = Tab(deepLink: link) {
            selectedTab = tab
        }
    }
}

struct FastTabView: View {
    @ObservedObject var fastManager: FastManager

    var body: some View {
        NavigationStack {
            FastTrackerView(fastManager: fastManager)
                .navigationTitle("Solstice")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HistoryTabView: View {
    @ObservedObject var fastManager: FastManager

    var body: some View {
        NavigationStack {
            HistoryListView(fastManager: fastManager)
                .navigationTitle("History")
        }
    }
}

struct SettingsTabView: View {
    @ObservedObject var fastManager: FastManager

    var body: some View {
        NavigationStack {
            SettingsView(fastManager: fastManager)
        }
    }
}

#Preview {
    ContentView(context: PersistenceController.preview.container.viewContext)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
