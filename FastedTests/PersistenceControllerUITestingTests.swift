import XCTest
import CoreData
@testable import Fasted

/// `PersistenceController.uiTesting(storeIdentifier:)` is the seam `ContentView` uses to keep UI
/// test runs off the real `.shared` store. These tests are a fast, deterministic proxy for the two
/// guarantees the UI test suite actually depends on at runtime — reopening the same identifier
/// resumes the same data (the relaunch-persistence check), and different identifiers never see each
/// other's data (test-to-test isolation) — without needing a simulator to prove either one.
@MainActor
final class PersistenceControllerUITestingTests: XCTestCase {
    private var createdIdentifiers: [String] = []

    override func tearDownWithError() throws {
        for identifier in createdIdentifiers {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("uitest-\(identifier)", isDirectory: false)
                .appendingPathExtension("sqlite")
            try? FileManager.default.removeItem(at: url)
        }
        for (suite, dir) in createdSuites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: dir)
        }
        createdSuites = []
        createdIdentifiers = []
        try super.tearDownWithError()
    }

    private func makeController(identifier: String = UUID().uuidString) -> PersistenceController {
        createdIdentifiers.append(identifier)
        return PersistenceController.uiTesting(storeIdentifier: identifier)
    }

    private func makeManager(identifier: String = UUID().uuidString) -> FastManager {
        let suite = "PersistenceUITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let commandsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)
        let coord = AppGroupCoordinator(
            userDefaults: defaults,
            appGroupId: suite,
            commandsDirectory: commandsDir
        )
        createdSuites.append((suite, commandsDir))
        return FastManager(
            context: makeController(identifier: identifier).container.viewContext,
            defaults: defaults,
            coordinator: coord
        )
    }

    private var createdSuites: [(String, URL)] = []

    func testFreshIdentifierStartsWithNoActiveFast() throws {
        let manager = makeManager()
        XCTAssertNil(manager.activeFast)
    }

    /// This is what makes the UI test's `app.terminate()` + relaunch assertion meaningful: a fast
    /// written through one `PersistenceController` instance must still be there when a second
    /// instance opens the same identifier, exactly as a relaunched process would.
    func testReopeningTheSameIdentifierSeesPreviouslyWrittenData() throws {
        let identifier = UUID().uuidString

        let firstManager = makeManager(identifier: identifier)
        firstManager.startFast(startDate: Date(), targetDuration: 16 * 3600, protocolType: "16:8")
        XCTAssertNotNil(firstManager.activeFast)

        let secondManager = makeManager(identifier: identifier)
        secondManager.refresh()
        XCTAssertNotNil(secondManager.activeFast, "reopening the same identifier must resume the same store")
    }

    func testDifferentIdentifiersAreFullyIsolated() throws {
        let firstManager = makeManager()
        firstManager.startFast(startDate: Date(), targetDuration: 16 * 3600, protocolType: "16:8")
        XCTAssertNotNil(firstManager.activeFast)

        let secondManager = makeManager()
        XCTAssertNil(secondManager.activeFast, "a different identifier must not see another store's data")
    }
}
