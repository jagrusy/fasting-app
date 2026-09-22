# GRU-26 handoff

- Issue / task: GRU-26 — Make persistence failures explicit and preserve committed state.
- Branch / worktree / base SHA / head SHA: `codex/gru-26-persistence-errors`; this worktree; base `2bad237422a0fdeff7a462a8c2fbc80957e06098`; head is the PR head recorded in Linear.
- Claimed paths and concurrent-work check: FastManager persistence/validation paths, affected SwiftUI callers, and focused tests. No overlapping implementation was active when claimed in Linear.
- Prerequisites: GRU-25 merged in `2bad237422a0fdeff7a462a8c2fbc80957e06098` via PR #61.
- Changed behavior and rationale: Mutations return committed success or failure, failed saves roll back, read failures reject validation, and side effects run only after a commit. A recoverable app-level alert keeps edit/delete views open when persistence fails. Applying a protocol to settings and an active fast is one transaction.
- Changed contracts/schema/identities: `FastManager.startFast` now returns `Fast?`; mutation methods return `Bool`; `PersistenceController.saveContext` throws. No Core Data schema, store identity, bundle ID, App Group, or wire-format change.
- Tests: Xcode 26.1.1 (17B100), XcodeGen 2.44.1, SwiftLint 0.65.1; iPhone 17 Pro simulator, iOS 26.1, UDID `00C480BE-5EE8-4EAD-A597-FF056B517A60`.
  - `swiftlint lint --strict --no-cache` — passed, zero violations.
  - `xcodebuild test -project Fasted.xcodeproj -scheme FastedTests -destination 'platform=iOS Simulator,id=00C480BE-5EE8-4EAD-A597-FF056B517A60' -resultBundlePath /private/tmp/gru26.h2SVLG/unit-2.xcresult` — passed, 142/142.
  - `xcodebuild test -project Fasted.xcodeproj -scheme FastedUITests -destination 'platform=iOS Simulator,id=00C480BE-5EE8-4EAD-A597-FF056B517A60' -only-testing:FastedUITests/FastedUITests/testStartAndEndFastFlow -only-testing:FastedUITests/FastedUITests/testSettingsTabProtocolSelection -resultBundlePath /private/tmp/gru26.h2SVLG/ui-smoke.xcresult` — passed, 2/2.
  - `xcodebuild build -project Fasted.xcodeproj -scheme Fasted -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/gru26.h2SVLG/DerivedDataRelease CODE_SIGNING_ALLOWED=NO` — passed; built iOS, widgets, Watch, and Watch widgets.
  - `xcodegen generate` — passed; a before/after project checksum matched.
- First failures and resolution: The initial full suite failed one existing test (three assertions) because its unsaved `Fast` omitted required `createdAt`/`updatedAt` values; explicit save failure now correctly rolled it back. The fixture now supplies valid required fields and resets its shared preview context. The complete suite passed on the next full run. Simulator access initially failed inside the filesystem sandbox; rerunning with approved CoreSimulator access succeeded.
- Acceptance checklist: PASS explicit mutation results; PASS fetch errors reject validation; PASS rollback preserves committed state and suppresses optimistic snapshots/side effects; PASS injected read/save failures with disk-store reopen; PASS recoverable UI alert and dismissal gated on commit.
- Remaining blockers, risk and recovery/compatibility notes: Independent data-contract review and owner merge decision are still required. Recovery is retrying the operation; the prior committed store remains authoritative. Existing tests emit known multi-container Core Data and unpaired Watch simulator diagnostics without failures.
- Independent reviewer / PR: pending PR creation and independent review.
- Downstream handoff: GRU-27 may rely on the explicit mutation results, but durable command acknowledgment remains outside this issue.
