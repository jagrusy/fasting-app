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
- Remaining blockers, risk and recovery/compatibility notes: Independent data-contract review passed on 28 September; owner merge decision remains required. Recovery is retrying the operation; the prior committed store remains authoritative. Existing tests emit known multi-container Core Data and unpaired Watch simulator diagnostics without failures.
- Independent reviewer / PR: Codex review_persistence, read-only review against current main; no remaining blockers. PR #62.
- Downstream handoff: GRU-27 may rely on the explicit mutation results, but durable command acknowledgment remains outside this issue.

## 28 September main reconciliation

- Isolated worktree `/private/tmp/fasted-gru26-reconcile`, branch `codex/gru-26-main-reconciliation`; integrates main `573910b5a74281adc430772d60f33e3c7efc30d8` into previous PR head `79f7046a589bbb4576dafd9adfa6be69bf907d24`.
- Preserved removal of Live Activities, custom/extended start menu and notification scheduling from main. Retargeting now performs full notification reconciliation after commit. Snapshot failures after a successful write no longer say saved data is unchanged. Capture the deleted UUID before saving so snooze cleanup remains reliable.
- Added injectable notification delivery, Watch/review effects and external-command observation for isolated failure tests. No schema, permission, identity or shared wire changes.
- Same toolchain/device as above. `xcodegen generate`, `swiftlint lint --strict --quiet`, and `git diff --check` passed.
- `xcodebuild test -project Fasted.xcodeproj -scheme FastedTests -destination 'platform=iOS Simulator,id=00C480BE-5EE8-4EAD-A597-FF056B517A60' -resultBundlePath /private/tmp/fasted-gru26-validation/unit-4.xcresult -quiet` passed 168/168, no skips.
- `xcodebuild build -project Fasted.xcodeproj -scheme Fasted -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet` passed; log `/private/tmp/fasted-gru26-validation/release.log`. This is unsigned simulator compile evidence, not device/release acceptance.
- First reconciliation build exposed a main test assuming nonoptional start success; changed it to XCTUnwrap. Subsequent run passed. First new notification regression test incorrectly expected a day-one milestone; corrected to the production day-two policy for a 72-hour fast. Result bundles `unit`, `unit-2`, `unit-3`, and `unit-4` retain all attempts.
- Disk fixtures reopen another container while the original is alive; they prove durable disk visibility, not process termination. UI relaunch evidence is recorded separately below.
- Independent review rechecked all fixes and injection wiring, with no remaining blockers. Existing command acknowledgment/read-readiness concerns remain outside this change. Owner merge gate remains open; any challenge work is explicitly stacked preparation until this prerequisite is merged.

- UI command: `xcodebuild test -project Fasted.xcodeproj -scheme FastedUITests -destination 'platform=iOS Simulator,id=00C480BE-5EE8-4EAD-A597-FF056B517A60' -only-testing:FastedUITests/FastedUITests/testStartAndEndFastFlow -only-testing:FastedUITests/FastedUITests/testDiscardFastDoesNotCreateHistoryAfterRelaunch -only-testing:FastedUITests/FastedUITests/testStartMenuStartsAnExtendedFast -resultBundlePath /private/tmp/fasted-gru26-validation/ui.xcresult -quiet` passed 3/3, no skips. Start/end and discard tests explicitly terminate and relaunch the isolated fixture.
