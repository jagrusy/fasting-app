import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: Tab = .fast

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
            FastTabView()
                .tabItem {
                    Label(Tab.fast.rawValue, systemImage: Tab.fast.icon)
                }
                .tag(Tab.fast)

            HistoryTabView()
                .tabItem {
                    Label(Tab.history.rawValue, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)

            SettingsTabView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
    }
}

struct FastTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "timer")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Fast Tracker")
                    .font(.title2.weight(.semibold))
                Text("Start, edit, and track your active fast.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Fast")
        }
    }
}

struct HistoryTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("History & Trends")
                    .font(.title2.weight(.semibold))
                Text("View your logs, calendar heatmap, and fasting streaks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("History")
        }
    }
}

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "gearshape")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("Configure your fasting protocol and notification reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
