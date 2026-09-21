import SwiftUI
import CoreData

@main
struct FastedApp: App {
    init() {
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            // `ContentView` resolves and injects its own `\.managedObjectContext` (including the
            // isolated store a `-uiTesting` launch uses instead of `.shared`). This used to also
            // eagerly load `PersistenceController.shared` here regardless of which store
            // `ContentView` actually chose, unconditionally instantiating a second
            // `NSPersistentContainer` for the same Core Data model alongside the one `ContentView`
            // was using — confirmed live to crash `NSFetchedResultsController.performFetch()` on a
            // relaunch reopening an isolated on-disk store.
            ContentView()
        }
    }
}
