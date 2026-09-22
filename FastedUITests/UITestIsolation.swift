import XCTest

/// Isolation helpers shared across UI test files, so any scenario can opt into an on-disk store
/// separate from `.shared`, other tests, and manual local use of the same simulator — see
/// `ContentView.resolveDefaultContext()` for the app-side half of this seam.
extension XCTestCase {
    /// Launches against an on-disk store isolated from `.shared`. Pass the same `storeId` across a
    /// `terminate()` + relaunch within one test to reopen the same store and verify persistence.
    func launchIsolatedApp(storeId: String = UUID().uuidString) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launchEnvironment = ["UITEST_STORE_ID": storeId]
        app.launch()
        return app
    }

    /// `List(.insetGrouped)` surfaces as a CollectionView in the accessibility tree, not a Table —
    /// confirmed against the live hierarchy rather than assumed. `FastRowView`'s
    /// `.accessibilityElement(children: .combine)` is exposed as two accessibility nodes sharing
    /// the same `fast_row_<uuid>` identifier (confirmed live: one `.cell`, one nested `.other`), so
    /// counting matched *elements* double-counts a single saved fast; counting distinct identifiers
    /// instead is immune to exactly how many nodes SwiftUI emits per row.
    func assertExactlyOneHistoryEntry(in app: XCUIApplication, message: String) {
        let historyList = app.collectionViews["history_fast_list"]
        XCTAssertTrue(historyList.waitForExistence(timeout: 5))
        let identifiers = historyEntryIdentifiers(in: historyList)
        XCTAssertEqual(identifiers.count, 1, message)
    }

    func assertNoHistoryEntries(in app: XCUIApplication, message: String) {
        let emptyState = app.staticTexts["No Completed Fasts Yet"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), message)

        let historyList = app.collectionViews["history_fast_list"]
        if historyList.exists {
            XCTAssertTrue(historyEntryIdentifiers(in: historyList).isEmpty, message)
        }
    }

    private func historyEntryIdentifiers(in historyList: XCUIElement) -> Set<String> {
        Set(
            historyList.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'fast_row_'"))
                .allElementsBoundByIndex
                .map(\.identifier)
        )
    }
}
