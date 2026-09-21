# DRAFT-02: Make timer tests deterministic and incapable of silent success

- Issue / task: DRAFT-02: Make timer tests deterministic and incapable of silent success (Solstice / Fasted Roadmap P0 - Lane A / Native State)
- Branch: `codex/draft-02-deterministic-tests`
- Worktree: `.worktrees/draft-02-deterministic-tests`
- Base SHA: `8742b5ba2daa72b9427bbf4fc1f7d9e3260a1555`
- Owned paths:
  - `Fasted/PersistenceController.swift`
  - `Fasted/ContentView.swift`
  - `Fasted/FastManager+Mocking.swift`
  - `FastedUITests/AppStoreScreenshotTests.swift`
  - `FastedUITests/FastedUITests.swift`
  - `FastedTests/TestStoreIsolationTests.swift`
  - `Fasted.xcodeproj/project.pbxproj`
  - `planning/agent-handoffs/DRAFT-02.md`
- Concurrent-work check: Verified. Lane A exclusive writer on Core Data store bootstrap, UI tests, and mock isolation. Root unowned changes (`MARKETING_PLAN.md`, `.gitignore`, `fantasy-agent/`, unstaged schemes) remain completely untouched in owner repository.

## Changed behavior and rationale

1. **Per-scenario test store isolation**:
   - `PersistenceController.makeShared()` supports launch arguments `-testStoreName <name>` and `-resetTestStore`, placing isolated stores under `Application Support/TestStores/<sanitized>.sqlite`.
   - Each UI test and screenshot capture run executes against an isolated SQLite store, eliminating state leakage across test cases and test suites.
2. **Deterministic UI testing without silent passes**:
   - Eliminated all conditional passes (`if button.waitForExistence(...)`) in `FastedUITests`.
   - Missing `start_fast_button` or `end_fast_button` controls fail tests unconditionally with explicit assertions.
   - Built full lifecycle verification in `testStartAndEndFastFlow`: clean launch -> start fast -> verify active timer & header -> end fast -> save fast -> verify history contains fast -> terminate app -> relaunch against same store -> verify persistence.
   - Built negative flow in `testDiscardFastFlow`: start fast -> end fast -> discard fast -> verify history contains no fasts -> terminate and relaunch -> verify empty history.
   - Built permission denial flow in `testStartFastWithDeniedNotificationsContinuesTimer`: start fast -> handle SpringBoard notification rejection -> assert timer continues running and fast can be saved.
   - Factored `FastedUITests.swift` into extensions to strictly adhere to SwiftLint `file_length` (<= 400 lines) and `type_body_length` (<= 250 lines).
3. **Release build safety**:
   - Wrapped `FastManager+Mocking.swift` (`seedMockDataForScreenshots`) entirely in `#if DEBUG`.
   - Wrapped mock seeding invocations in `ContentView.swift` in `#if DEBUG`.
   - Verified Release binary does not contain mock seeding symbols (`seedMockDataForScreenshots`).
4. **Unit test store isolation and persistence**:
   - Added `FastedTests/TestStoreIsolationTests.swift` covering independent store file creation, persistence across controller reload, cross-store isolation between separate SQLite databases, notification denial tolerance, and isolated screenshot seeding.
   - Handled store coordinator detachment (`coordinator.remove(store)`) during teardown to guarantee SQLite file handles close cleanly before directory unlinking.

## Changed contracts/schema/identities

- Core Data schema: Unchanged.
- Bundle identifiers / App Group: Unchanged (`group.com.grusy.SolsticeFast`).
- Scheme names: Unchanged.

## Verification

- Local tools: macOS 26.5.2 (25F84), Xcode 17B100 (Swift 6.0), iOS 26.1 Simulator (`iPhone 17 Pro`, UDID: `00C480BE-5EE8-4EAD-A597-FF056B517A60`).
- Project generation: `xcodegen generate` succeeded.
- Linting: `swiftlint lint --strict` succeeded with 0 violations across 100 files.
- Unit Tests:
  - Command: `xcodebuild test -project Fasted.xcodeproj -scheme FastedTests -destination 'platform=iOS Simulator,id=00C480BE-5EE8-4EAD-A597-FF056B517A60' -resultBundlePath build/unit-draft02.xcresult`
  - Result: 136/136 passed, 0 failures. Exit code 0.
- UI Tests:
  - Command: `xcodebuild test -project Fasted.xcodeproj -scheme FastedUITests -destination 'platform=iOS Simulator,id=00C480BE-5EE8-4EAD-A597-FF056B517A60' -resultBundlePath build/ui-draft02.xcresult`
  - Result: 17/17 passed, 0 failures. Exit code 0.
- Release Build:
  - Command: `xcodebuild build -project Fasted.xcodeproj -scheme Fasted -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
  - Result: Build succeeded. Exit code 0.
  - Symbol check: `nm .../Fasted.app/Fasted | grep -i seedMockDataForScreenshots` confirmed symbol is absent from Release binary.

## First failures and resolution

1. `TestStoreIsolationTests.testIsolatedStoresDoNotCrossPollute`: Core Data validation error on required attributes `createdAt` and `updatedAt`. Fixed by explicitly setting timestamps before saving.
2. `TestStoreIsolationTests` teardown: SQLite error `vnode unlinked while in use` when deleting directory while store was still open. Fixed by removing persistent stores from `NSPersistentStoreCoordinator` before unlinking directory.
3. `testStartAndEndFastFlow` & `testStartFastWithDeniedNotificationsContinuesTimer`: Checked for `"FASTING"`, but UI header renders `"Fasting in Progress"`. Updated test expectation to match active status string.

## Acceptance checklist

| Item | Result |
| --- | --- |
| Missing Start/End controls fail tests unconditionally (no silent passes) | Pass |
| Isolated test store per scenario (`-testStoreName`) | Pass |
| Full lifecycle test (start -> active -> end -> save -> history -> relaunch persistence) | Pass |
| Discard fast flow verification (does not save to history; persists empty after relaunch) | Pass |
| Denied notifications flow verification (timer runs and saves fast) | Pass |
| Seeding code stripped from Release builds (`#if DEBUG`) | Pass |
| 136/136 unit tests passing (`FastedTests`) | Pass |
| 17/17 UI tests passing (`FastedUITests`) | Pass |
| Release build compiles cleanly | Pass |
| SwiftLint passes with 0 violations (`--strict`) | Pass |
| Owner checkout and unowned files preserved | Pass |

## Remaining blockers, risk and recovery notes

- None. Work is fully validated, isolated in dedicated worktree `codex/draft-02-deterministic-tests`, and ready for review and merge.
