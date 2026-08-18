import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var fastManager: FastManager
    @State private var selectedTab: Tab = .fast
    @AppStorage("app_appearance") private var appearanceRaw: String = AppAppearance.dark.rawValue

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _fastManager = StateObject(wrappedValue: FastManager(context: context))
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
        .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-forceDarkMode") {
                appearanceRaw = AppAppearance.dark.rawValue
            }
            if ProcessInfo.processInfo.arguments.contains("-seedScreenshots80") {
                fastManager.seedMockDataForScreenshots(progress: 0.80)
            } else if ProcessInfo.processInfo.arguments.contains("-seedScreenshots100") {
                fastManager.seedMockDataForScreenshots(progress: 1.05)
            }
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
