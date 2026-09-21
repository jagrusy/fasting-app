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
        createdIdentifiers = []
        try super.tearDownWithError()
    }

    private func makeController(identifier: String = UUID().uuidString) -> PersistenceController {
        createdIdentifiers.append(identifier)
        return PersistenceController.uiTesting(storeIdentifier: identifier)
    }

    func testFreshIdentifierStartsWithNoActiveFast() throws {
        let manager = FastManager(context: makeController().container.viewContext)
        XCTAssertNil(manager.activeFast)
    }

    /// This is what makes the UI test's `app.terminate()` + relaunch assertion meaningful: a fast
    /// written through one `PersistenceController` instance must still be there when a second
    /// instance opens the same identifier, exactly as a relaunched process would.
    func testReopeningTheSameIdentifierSeesPreviouslyWrittenData() throws {
        let identifier = UUID().uuidString

        let firstManager = FastManager(context: makeController(identifier: identifier).container.viewContext)
        firstManager.startFast(startDate: Date(), targetDuration: 16 * 3600, protocolType: "16:8")
        XCTAssertNotNil(firstManager.activeFast)

        let secondManager = FastManager(context: makeController(identifier: identifier).container.viewContext)
        secondManager.refresh()
        XCTAssertNotNil(secondManager.activeFast, "reopening the same identifier must resume the same store")
    }

    func testDifferentIdentifiersAreFullyIsolated() throws {
        let firstManager = FastManager(context: makeController().container.viewContext)
        firstManager.startFast(startDate: Date(), targetDuration: 16 * 3600, protocolType: "16:8")
        XCTAssertNotNil(firstManager.activeFast)

        let secondManager = FastManager(context: makeController().container.viewContext)
        XCTAssertNil(secondManager.activeFast, "a different identifier must not see another store's data")
    }
}
