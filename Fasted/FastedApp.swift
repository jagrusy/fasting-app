import SwiftUI
import CoreData

@main
struct FastedApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {

            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
