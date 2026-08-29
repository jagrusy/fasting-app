# Companion Surfaces: Widgets, StandBy, Control Center, Watch

## How to resume this plan

This is built by a single agent working through the workstreams below in order, across as many sessions as it takes. **Start here every time:** check the boxes below to find the first unchecked workstream, read its section, and implement it completely — code, tests, commit, push — before moving to the next.

- [x] W-A — Notification quick wins
- [x] W0 — Build foundation
- [x] W1 — Shared state layer
- [x] W2 — Target skeletons




- [ ] W3 — App Intents layer
- [ ] W4 — Home Screen / Lock Screen / StandBy widget
- [ ] W5 — Control Center control
- [ ] W6 — watchOS companion
- [ ] W7 — Watch complications
- [ ] W8 — Release plumbing and doc reconciliation

Only check a box once that workstream's commit is actually pushed to `feat/companion-surfaces`. A resumed session trusts this checklist completely, so a box checked too early causes a workstream to be silently skipped, and a box left unchecked after the work is done causes it to be silently redone.

## Context

Solstice ("Fasted") today is a single iOS app target. To see or change your fast you must open the app, navigate to the Fast tab, and tap. Everything the app knows is locked behind that launch.

Two goals drive this work:

1. **Ambient awareness** — a fast should be visible at a glance and sit quietly in the back of your mind for its whole duration, without opening anything.
2. **Near-zero friction to start and stop** — starting a fast should not require launching an app.

The outcome: the app becomes a background presence — a widget on the Home and Lock Screen, a full-screen StandBy display on the nightstand, a complication on the watch face, and a one-press start from Control Center, the Action Button, or a notification banner.

### Live Activities are deliberately out of scope

This was the original headline idea and it has been **dropped on purpose**. ActivityKit caps a Live Activity at 12 hours (8 before iOS 18), and that limit is **not extendable** — not by push, not by background task. Apple's own guidance is to restart the activity, and the only reliable background restart is push-to-start, which requires running a server and would break the "100% on-device, no accounts" promise in `PRIVACY.md`. Against the default 16:8 protocol the activity would go dark around hour 12, precisely when the reminder matters most.

**So there is no Dynamic Island in this plan.** What replaces it:

| Goal | Surface | Expires? |
|---|---|---|
| Glance at progress | Home Screen widget, watch complication | Never |
| Ambient all-fast reminder | Lock Screen accessory widget, watch face | Never |
| Overnight presence | **StandBy** (charging, landscape — full-screen) | Never |
| One-press start/stop | Control Center, Action Button, Lock Screen control, notification action | — |

An `.accessoryRectangular` Lock Screen widget gives a permanent Lock Screen presence for all 16 hours, which serves the stated goal better than an activity that dies at hour 12. **StandBy is the answer to the overnight stretch** — a phone charging on the nightstand showing "Fat Burning · 6h 20m to goal" for the entire night, free with the widget work since it reuses the `.systemSmall`/`.systemMedium` families.

Every surface here is permanent. Nothing in this plan can visibly die mid-fast.

**AlarmKit was considered and deferred.** iOS 26 opened up the system-level alarm/timer treatment that was previously first-party-only (Apple's Clock app never used ActivityKit, which is why its timers hold the Dynamic Island indefinitely). AlarmKit grants third parties the Dynamic Island, Lock Screen, StandBy and Watch, with alerts that break through silent mode and Focus. It was rejected for four reasons: it requires an **iOS 26 floor** (a much steeper adoption cut than iOS 18); its alerts are **loud and breakthrough by design**, which is right for a cooking timer and wrong for "your fast is complete" — Apple's own guidance says alarms are not replacements for time-sensitive notifications; it needs a **second authorization prompt** (`NSAlarmKitUsageDescription`); and, decisively, **AlarmKit still renders its countdown through a Live Activity**, and whether that activity is exempt from the 12-hour cap is not stated in Apple's documentation — so it may not solve the original problem at all. Do not reach for AlarmKit in this build. If it is ever revisited, the prerequisite is a device spike answering that one question first.

### Decisions already made

- **Deployment target moves to iOS 18.0 / watchOS 11.0.** Required for Control Center / Action Button controls (`ControlWidget` is iOS 18+). Drops iPhone X/8 (capped at iOS 16).
- **No ActivityKit anywhere.** No `NSSupportsLiveActivities`, no `ActivityAttributes`, no `LiveActivityIntent`.
- **Watch app is complication-first and thin** — one screen (progress + start/end), not a port of `FastTrackerView`. With Live Activities gone there is no free Smart Stack mirroring, so **the watch complication is now the only wrist surface** and rises in priority accordingly.
- **Ending a fast from a widget is state-aware** — goal met: one tap completes in place; goal not met: opens the app to the existing Save/Discard confirmation in `Fasted/EndFastButtonView.swift`.
- **Build is a single Sonnet agent** (see "Agent setup") working through the checklist above sequentially, resuming across sessions as needed — not a fleet of parallel agents. The workstreams below still describe disjoint file sets per surface; that's kept because it makes each workstream's diff reviewable on its own, not because anything runs in parallel anymore.

### Design intent worth preserving

`Fasted/MetabolicStage.swift` already models five stages (Sugar Reset → Glycogen → Fat Burning → Autophagy → Deep Ketosis) and is unused outside the app. It is the differentiator. Every surface here should lead with the **stage**, not just a number — "Fat Burning · 4h 12m to goal" gives the timer a narrative. A stage *transition* is the one genuinely notification-worthy moment mid-fast; W-A turns those into the ambient reminder.

---

## Non-negotiables

1. **Never hand-edit `Fasted.xcodeproj/project.pbxproj`.** After W0, CI regenerates it. It is 41KB of UUID-keyed plist; blind edits will break the repo.
2. **Never claim a build passed.** No agent can run `xcodebuild`, `xcodegen`, `swift`, or `swiftlint` — none are installed and the platform is Linux. The only verification is a pushed branch's CI run. Each workstream's commit message must state what CI proves and list anything that still needs device verification; add the device-only items to this plan's Verification section too, so they aren't lost between sessions.
3. **All work happens on the integration branch `feat/companion-surfaces`, never `main`.** Commit after each workstream and push immediately — nothing should sit unpushed between sessions. `.github/workflows/deploy.yml` ships every push to `main` straight to TestFlight, so never push there, and do not open a pull request unless explicitly asked to — the branch itself is the deliverable until the human says otherwise.
4. **Lint is `swiftlint lint --strict`** — the 120-column `line_length` *warning* is a hard failure, and `force_unwrapping` + `implicitly_unwrapped_optional` are enabled. WidgetKit type names are long; use `typealias`.
5. **`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` is project-wide.** With a uniform iOS 18 floor, **no `#available` check for WidgetKit, App Intents, or ControlWidget is needed anywhere** — and an always-true one is a *build failure*. Do not add availability gating for these APIs.
6. **`Shared/` must compile for iOS 18.0 *and* watchOS 11.0.** No unguarded `import UIKit`, and **never** reference `Fast`, `UserSettings`, `NSManagedObject`, or `PersistenceController` — those Core Data codegen classes exist only in the `Fasted` target.
7. **No ActivityKit.** If it's tempting to reach for a Live Activity, it's out of scope by decision, not oversight.

---

## Agent setup (do this once, before W0)

Create `.claude/agents/solstice-builder.md` with `model: sonnet` in frontmatter and a body carrying the non-negotiables above, the repo's toolchain facts, and the SwiftLint constraints. Then invoke that agent — it reads this plan, resumes from the checklist at the top, and works through the workstreams in order. Invoke it again any time (a fresh session or a continued one both work identically) to pick up exactly where it left off; there's no need to specify which workstream, since the checklist determines that.

This matters because the top failure modes are *process* failures, not coding failures: hand-editing the pbxproj, adding always-true `#available` checks, claiming a build passed in an environment with no compiler, or losing track of progress across a build long enough to span several context windows.

---

## Build order

Work through the workstreams strictly in the order given by the checklist. The reasoning:

- **W-A** has no dependencies on anything else here — do it whenever, first is fine, since it ships real value immediately with zero build risk.
- **W0 → W1 → W2 → W3 are hard, sequential prerequisites.** W0 makes `project.yml` and CI agree with each other, so nothing declared afterward is trustworthy until it lands. W1 is the correctness core — the shared snapshot and command queue — and deliberately introduces no new build targets, so it's worth getting right before any extension exists to consume it. W2 declares every new target (widgets, watch app, watch widget extension) as compiling placeholders in one step; it's the highest build-risk workstream in the project, which is exactly why it's isolated to its own commit rather than mixed into W4–W6. W3 builds the App Intents that W4–W6 wire buttons to.
- **W4 → W5 → W6** each build one surface — widget/StandBy, Control Center, watchOS app — on top of W3's intents. They touch disjoint files, so this exact order is a preference, not a hard requirement: W6 (watch) is placed after W4 because it reuses `Shared/FastProgressViews.swift`, which W4 writes.
- **W7** (watch complications) needs W6's watch app target and reuses W4's view code, so it comes after both.
- **W8** is release plumbing and only makes sense once everything else compiles.

---

## W-A — Notification quick wins

Do this one first — it's independent of everything else, ships real value immediately, and carries zero build risk (no new targets, no entitlements) while W0–W3 handle the more involved plumbing.

**Goal:** one-tap start from a Lock Screen banner, and stage transitions as the ambient reminder.

**Files:** `Fasted/NotificationManager.swift`, `Fasted/FastManager+Notifications.swift`, `Fasted/FastManager.swift`, `Fasted/NotificationSettingsSection.swift`, `Fasted/NotificationSchedule.swift`.

1. **Start action on the existing reminder.** `scheduleRecurringReminders` already fires "Time to Start Fasting ⏱️" nightly (`recurring_start_day_<1-7>`) but only reminds. Add a `START_FAST_CATEGORY` with a `START_FAST_ACTION`, set it as `categoryIdentifier` on those requests, and route it through a new `onStartFastRequested` closure wired in `FastManager.setupNotificationCallbacks()` — exactly mirroring the existing `onEndFastRequested` → `endFast()` path. One tap from the banner; the app never opens.

2. **Stage-transition notifications.** On `startFast` (and `updateActiveFast`, which can shift the start time), schedule a `UNTimeIntervalNotificationTrigger` for each `MetabolicStage.startSeconds` boundary still in the future, using the stage's `title` and `summary`. Identifiers `fast_stage_<rawValue>`; cancel all in `endFast`, `discardActiveFast`, `deleteFast`. Gate behind a new `notifyOnStageChange` flag on `NotificationSchedule` (defaults **on**). It is persisted as JSON `Binary` on `UserSettings`, so a missing key must decode to the default — give it a default value and test the round-trip. Surface the toggle in `NotificationSettingsSection.swift`.

**Verify:** unit tests in `FastedTests` — a 16h fast started now schedules boundaries at 4h/12h; one started 13h ago schedules only 18h and 24h; ending cancels all; an old `NotificationSchedule` payload without `notifyOnStageChange` decodes to `true`. Delivery itself is device verification.

---

## W0 — Build foundation

**This is the critical finding.** `.github/workflows/ci.yml` builds the committed `.pbxproj` and **never runs XcodeGen**. `scripts/pre-commit.sh` regenerates it only on a developer machine that has xcodegen installed. So today, a `project.yml` edit produces a **green CI run that built the old project** — the target silently does not exist. Nothing else can proceed until this is fixed.

**Files:** `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`, `project.yml`, `.swiftlint.yml`, plus `git mv` into a new `Shared/`.

1. **CI runs XcodeGen.** Add `brew install xcodegen` + `xcodegen generate` to both the `build-and-test` job in `ci.yml` and the deploy job in `deploy.yml`, after checkout and before any `xcodebuild`. Add a **non-blocking** drift check (`continue-on-error: true`) warning if the committed `.pbxproj` is stale, so a human's Xcode still opens a current project.

2. **Commit explicit shared schemes.** CI currently works only because `xcodebuild` silently autocreates schemes into gitignored `xcuserdata/` — not a foundation for three new targets. Add a top-level `schemes:` block. **Scheme names `Fasted`, `FastedTests`, `FastedUITests` must be preserved verbatim** — they are referenced by `ci.yml`, `deploy.yml`, `Makefile`, and `fastlane/Fastfile`.

3. **De-iOS-ify the project-level `settings.base`.** It currently applies `IPHONEOS_DEPLOYMENT_TARGET`, `SUPPORTED_PLATFORMS: "iphonesimulator iphoneos"`, `TARGETED_DEVICE_FAMILY: "1"` and `SUPPORTS_MACCATALYST` to *every* target — a watchOS target inheriting these fails with a misleading "does not support the platform" error. Delete those four keys from the base block. This is a **provable no-op**: all three existing iOS targets already redeclare each in their own `settings.base`. Add `SUPPORTS_MACCATALYST: "NO"` to each of the three (the only key they lack). Set `options.deploymentTarget` to `iOS: "18.0"`, `watchOS: "11.0"`, and update each iOS target's `IPHONEOS_DEPLOYMENT_TARGET` to `18.0`.

4. **Create `Shared/`** and `git mv` three files in unchanged: `Fasted/FastingProtocol.swift`, `Fasted/MetabolicStage.swift`, `Fasted/SolsticeTheme.swift`. Add `Shared` to the `Fasted` target's `sources`. Grep `SolsticeTheme.swift` for `UIKit`/`UIColor`/`UIScreen` and wrap any hit in `#if canImport(UIKit) && !os(watchOS)`. Write `Shared/README.md` stating non-negotiable #6.

5. `.swiftlint.yml` `included:` becomes `[Fasted, Shared, FastedTests, FastedUITests]`. **Remove the stale `FastedWatch`/`FastedWatchTests` entries** — W2 adds the real ones, and there will be no `FastedWatchTests` target.

**Verify:** CI green with zero behavior changes. `FastedTests` does `@testable import Fasted` and uses `FastingProtocol`, `MetabolicStage`, `SolsticeColors` — it still compiling is the proof the file move worked.

Note: `README.md` and `CONTRIBUTING.md` currently claim a watchOS companion and Swift Charts that **do not exist**, and `Makefile`'s `build-watch` swallows failure with `|| echo`. Leave these to W8; just don't trust them.

---

## W1 — Shared state layer

The correctness core, and the most load-bearing workstream in the plan. Ships **no new build targets**, so it is low build-risk and high test-coverage.

### Why we do NOT move Core Data into the App Group

`Fasted/PersistenceController.swift` uses `NSPersistentContainer(name: "Fasted")` at the default location inside the app container, and `fatalError`s if the store fails to load. The app is live with real users. Relocating the store requires a one-shot migration (store + `-wal` + `-shm`, partial-failure handling, downgrade rollback) — a data-loss bug class, for no user-visible benefit. Widgets need ~6 scalars; extensions need to *express intent*, not query history. Independently: a WidgetKit extension runs under a tight memory limit and can be jetsammed mid-transaction, so handing it a writable handle to the user's only copy of their history is a bad trade.

Instead: **a read-only snapshot out, a durable command queue in.**

### Why the queue is mandatory

With Live Activities dropped, there is no `LiveActivityIntent`, and **process placement is not guaranteed**: an `AppIntent` fired from a widget button runs in the app's process only if the app happens to be running, and in the **widget extension process otherwise** — where Core Data is unreachable. A `ControlWidget`'s `SetValueIntent` is in the same position.

So the queue is not a fallback or an optimization. It is **the only durable channel from an extension to the app**, and every intent must be written assuming it will run somewhere that cannot see Core Data.

### Types (all in `Shared/`)

- **`FastSnapshot`** (`Codable, Equatable, Sendable`) — `schemaVersion`, `generation` (monotonic, app-only), `updatedAt`, `fastID: UUID?` (nil == not fasting), `startDate`, `targetDuration` (excludes snooze), `snoozeOffset`, `protocolType`; computed `isFasting`, `goalDate`. Decoding rule: a `schemaVersion` **newer** than the reader's decodes to `nil`, so an older extension binary can't misread a newer app's snapshot during an update.
- **`FastCommand`** — `id: UUID` (idempotency key), `kind` (`start`/`end`/`snooze`/`discard`), **`effectiveDate: Date`** (the moment of the tap), `targetFastID: UUID?`, `payloadSeconds`, `protocolType`, `source`.
- **`AppGroup.identifier = "group.com.grusy.SolsticeFast"`**.
- **`SharedStore`** — `readSnapshot()`, `writeSnapshot(_:)` (app only), `enqueue(_:)` (any process), `drainQueue()`, `markApplied(_:)`. Fully injectable `init(defaults:containerURL:)`, mirroring the existing `defaults:` injection `FastedTests` already exploits — so it unit-tests with no App Group entitlement.

### Storage split — deliberate

- **Snapshot → App Group `UserDefaults`.** Single writer, many readers.
- **Queue → a JSON file in the App Group container, guarded by `NSFileCoordinator`.** This matters: appending to a `UserDefaults` array is a non-atomic read-modify-write across processes, and a lost "end fast" is a user-visible data bug. Cap at 32 commands (oldest dropped) so it can't grow unbounded if the app is never opened.
- **Applied-ID ledger → App Group `UserDefaults`**, a bounded ring of the last 64 UUIDs, for idempotency.

### The hard question, answered

> User ends the fast from a widget while the app is not running. What is the end timestamp, and what shows on screen next launch?

**End timestamp = `effectiveDate`, captured by `Date()` inside `perform()` at the moment of the tap** — never the app's later launch time. That is the entire reason `effectiveDate` is on the wire.

**Next launch shows** an idle tracker and a completed fast in History ending at the tap time, with no flash of a stale active fast, because of the ordering rule below.

- **Idempotency/conflict:** `targetFastID` is checked against the real `activeFast.id`. Mismatch (already ended on the phone) → silent no-op, marked applied. Commands apply in `effectiveDate` order, so a queued `start` then `end` yields one correct completed fast. Every applied command runs through the existing `FastManager.validateInterval(...)` in `Fasted/FastManager+Validation.swift`; invalid ones are dropped and the app rewrites the authoritative snapshot from Core Data, so the system self-heals.
- **Stranded commands:** if the app is never opened, the command waits — but the snapshot was already updated optimistically, so **no surface ever lies to the user**. This is the deliberate trade for not sharing the Core Data store.
- **The one honest cost:** History isn't updated until the app next runs. Nothing outside the app reads History, so this is invisible.

### `FastManager` integration

Add a fourth injected dependency `sharedStore: SharedStore = .shared`. New file `Fasted/FastManager+SharedState.swift` (keeps the diff to `FastManager.swift` small and reviewable):

- `publishSnapshot()` — build from `activeFast` + `snoozeOffset(for:)` + `userSettings.selectedProtocol`, bump `generation`, write, then `WidgetCenter.shared.reloadAllTimelines()`. Call at the end of `startFast`, `endFast`, `discardActiveFast`, `deleteFast`, `updateActiveFast`, `snoozeFast`, `updateSelectedProtocol`, `updateCompletedFast`, `clearAllFastingData`, `refresh`.
- `applyPendingCommands()` — drain, apply, mark applied; guarded by an `isDraining` flag.

**Ordering rule in `refresh()` — this prevents the stale-fast flash:**

```swift
public func refresh() {
    applyPendingCommands()   // FIRST — before anything is @Published
    fetchActiveFast()
    fetchUserSettings()
    publishSnapshot()        // LAST — authoritative, overwrites any optimistic write
}
```

No recursion risk: `startFast`/`endFast`/`snoozeFast` do not call `refresh()`.

`Fasted/PendingCommandDrainer.swift` — a standalone, non-`@MainActor` type owning its own `NSManagedObjectContext`, called both by `FastManager.applyPendingCommands()` and by any background-launched intent that *does* land in the app process. One code path, two entry points. It posts `Notification.Name.fastStateDidChangeExternally`, observed by `FastManager`, so a background mutation while the UI is alive triggers a `refresh()`.

`Fasted/ContentView.swift`'s `.onChange(of: scenePhase)` currently only calls `syncNotifications()` — add `fastManager.refresh()` before it. **This is the primary drain trigger**, so it must not be missed.

### Entitlements

New `Fasted/Fasted.entitlements` with `com.apple.security.application-groups = [group.com.grusy.SolsticeFast]`; wire `CODE_SIGN_ENTITLEMENTS` in `project.yml`. **No `NSSupportsLiveActivities`** — Live Activities are out of scope.

**Verify:** simulator builds don't validate App Group entitlements, so CI stays green. New `FastedTests/SharedStateTests.swift`: snapshot round-trip; forward-version decodes to `nil`; `startFast` populates the snapshot; `snoozeFast(by: 1800)` sets `snoozeOffset` **without** mutating `targetDuration` (guards the deliberate existing design in `FastManager+Notifications.swift`); **enqueue `.end` with `effectiveDate` 20 min ago → drain → persisted `endDate` equals `effectiveDate`** (the money test); double-enqueue applies once; mismatched `targetFastID` no-ops; `start`-then-`end` yields one correct fast; 40 enqueues retain 32.

---

## W2 — Target skeletons

Declares **every** new target and **every** new source file with compiling placeholders, so every workstream after this one only ever adds code inside already-declared targets and never needs to touch `project.yml` again. **Highest build-risk workstream in the project** — deliberately isolated to its own commit so a failure here is easy to isolate and revert without losing the W0/W1 work underneath it.

**`FastedWidgets`** — `type: app-extension`, platform iOS, deployment 18.0, sources `[FastedWidgets, Shared]`, bundle id `com.grusy.SolsticeFast.Widgets`, own entitlements with the same App Group, `SKIP_INSTALL: YES`, hand-written `Info.plist` with `NSExtensionPointIdentifier = com.apple.widgetkit-extension` (no principal class — SwiftUI `WidgetBundle` uses `@main`).

**`FastedWatch`** — `type: application`, platform watchOS, deployment 11.0, sources `[FastedWatch, Shared]`, bundle id `com.grusy.SolsticeFast.watchkitapp`, `SDKROOT: watchos`, `SUPPORTED_PLATFORMS: "watchsimulator watchos"`, `TARGETED_DEVICE_FAMILY: "4"`. `Info.plist` needs `WKApplication = true` and `WKCompanionAppBundleIdentifier = com.grusy.SolsticeFast`. Do **not** set `WKWatchKitApp` (legacy two-target layout) and do **not** copy `UIRequiredDeviceCapabilities` / `LSRequiresIPhoneOS` / orientation keys from the app's plist.

**`FastedWatchWidgets`** — watchOS app-extension, `com.grusy.SolsticeFast.watchkitapp.Widgets`, for W7's complications. Declare it here with a placeholder so W7 needs no `project.yml` edit either. Because the watch app and its widget extension are two processes on the **same** device, both `FastedWatch` and `FastedWatchWidgets` need App Group entitlements — this is the one place a watch-side App Group is required.

Add all three as `dependencies` of `Fasted` so they're embedded, add matching schemes, add them to `.swiftlint.yml`, and add a watch `AppIcon` asset set (App Store Connect rejects a watch app without one).

**Placeholder files created here, each filled in by exactly one later workstream** (this keeps each workstream's diff small and focused, even though one agent does all of them):

| File | Filled in by |
|---|---|
| `FastedWidgets/FastedWidgetsBundle.swift` (the `@main WidgetBundle`) | **finished in W2, touched by nobody after** |
| `FastedWidgets/FastStatusWidget.swift` | W4 |
| `FastedWidgets/FastControlWidget.swift` | W5 |
| `FastedWatch/FastedWatchApp.swift`, `FastedWatch/WatchRootView.swift` | W6 |
| `Fasted/WatchSessionManager.swift` | W6 |
| `FastedWatchWidgets/FastComplications.swift` | W7 |

**Verify:** CI gains explicit `xcodebuild build` steps for `FastedWidgets`, `FastedWatch`, and `FastedWatchWidgets`. Use **`-destination "generic/platform=watchOS Simulator"`** for the watch targets — not a device name; `Makefile`'s hardcoded `Apple Watch Series 10 (46mm)` will not exist on `macos-15` runners.

---

## W3 — App Intents layer

Four intents in `Shared/Intents/`, compiled into both the app and the widget extension, each doing nothing but enqueue a `FastCommand` and refresh surfaces.

- `StartFastIntent`, `EndFastIntent`, `SnoozeFastIntent(minutes:)` — plain `AppIntent`.
- `SetFastingIntent` — `AppIntent, SetValueIntent` (`Value == Bool`), for the Control Center toggle.

**Every `perform()` must assume it is running in the widget extension with no Core Data access.** The body is uniform: read snapshot → `enqueue` the command with `effectiveDate: Date()` → write an optimistic snapshot so surfaces update instantly → `WidgetCenter.reloadAllTimelines()` → attempt a drain (no-ops when Core Data isn't reachable). Never write Core Data directly from an intent, and never skip the enqueue in favor of the snapshot alone — **the snapshot is cosmetic and always overwritten by the app; the queue is the only durable channel.**

The **state-aware end** decision lives here: `EndFastIntent` checks the snapshot's `goalDate`. Past goal → enqueue `.end` and complete in place. Before goal → return an `OpensIntent` that launches the app onto the existing Save/Discard confirmation in `Fasted/EndFastButtonView.swift`, rather than ending silently.

**Verify:** extract logic out of `perform()` into pure functions (`FastCommandFactory.endCommand(from:at:)`, `FastSnapshot.endingNow()`, `FastSnapshot.snoozed(by:)`) and unit-test those. Do not try to unit-test `perform()` itself.

---

## W4–W6 — Widget, Control, Watch

Three surfaces, each in its own files. Nothing about this is parallel anymore, but the file boundaries below are kept clean anyway — it makes each workstream's commit reviewable on its own even when one agent writes all three back to back.

### W4 — Home Screen / Lock Screen / StandBy widget

**The headline workstream.** Owns `FastedWidgets/FastStatusWidget.swift`, `Shared/WidgetTimelineBuilder.swift`, `Shared/FastProgressViews.swift`.

Families: `.systemSmall`, `.systemMedium` (these two also serve **StandBy** when the phone is charging in landscape — verify legibility at StandBy's dimmed, high-contrast night rendering), plus `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` for the Lock Screen.

**Self-updating backbone — the key technique.** `Text(timerInterval:)` and `ProgressView(timerInterval: startDate...goalDate)` tick **without waking any process and without timeline reloads**. Elapsed time and the progress ring are therefore always correct with zero refresh budget spent. Reloads are needed only when *content* changes (stage crossing, goal, start/end).

`WidgetTimelineBuilder.entries(for:now:)` is a **pure function** and the point of this workstream's testability: an entry at each future `MetabolicStage.startSeconds` boundary plus `goalDate`, `.after(nextBoundary)` reload policy, single `.never` entry when idle. Push reloads come from `publishSnapshot()` in W1, so the timeline needn't be aggressive.

Lead with the **metabolic stage** in `.systemMedium`, `.accessoryRectangular`, and StandBy. Idle state shows a `Button(intent: StartFastIntent())`. Accessory families get a tap-to-open deep link rather than a button (they're too small for reliable button targets).

Put the shared ring/stage view code in `Shared/FastProgressViews.swift` — W6 and W7 both reuse it, so it must compile for watchOS.

**Verify:** `FastedTests/WidgetTimelineBuilderTests.swift` — boundaries for a 16h fast started 3h ago; no past-dated entries; idle; goal-passed. Rendering, StandBy, and Lock Screen placement are device verification.

### W5 — Control Center control

**Owns:** `FastedWidgets/FastControlWidget.swift`. Smallest workstream, and **the strongest answer to "minimal friction to start."**

A `ControlWidget` with a `ControlWidgetToggle` bound to a `ControlValueProvider` reading `SharedStore.shared.readSnapshot()?.isFasting`, driven by `SetFastingIntent` from W3. Lands in Control Center, the Lock Screen control slot, and the Action Button. The provider must handle a `nil` snapshot (first install, app never run) by rendering "not fasting" and letting the toggle start one.

**Verify:** compilation only. A control cannot be unit-tested and CI's simulator won't exercise it — this is almost entirely device verification, and the commit message must say so plainly.

### W6 — watchOS companion

**Owns:** `FastedWatch/*`, `Fasted/WatchSessionManager.swift`, `Shared/WatchPayload.swift`.

One screen: ring, elapsed time, stage, single start/end button. **Not** a port of `FastTrackerView`. Reuse `Shared/FastProgressViews.swift` from W4.

**Transport reuses W1's types verbatim** — the payoff of the shared-state design:
- Phone → watch: `updateApplicationContext(["snapshot": <encoded FastSnapshot>])` on every `publishSnapshot()`. Latest-state-wins coalescing is exactly right for a snapshot.
- Watch → phone: encode a **`FastCommand`**, `sendMessage` when reachable, else `transferUserInfo` (queued, guaranteed, survives relaunch). The phone-side delegate calls `SharedStore.enqueue` then drains — the *same* command type and *same* drain code as the widget. `effectiveDate` is again the tap time, so a fast ended on the wrist with the phone in another room records the correct end timestamp.

Watch-local persistence is plain `UserDefaults.standard` on the watch, holding the last snapshot so the UI is correct before the session activates. (The App Group entitlement on `FastedWatch` exists for W7's complication extension, not for phone sync.)

**Verify:** `WatchPayload` round-trip tests run in `FastedTests` on iOS. **There is deliberately no `FastedWatchTests` target** — a watchOS test bundle would need a watchOS simulator destination in CI, roughly doubling test time for logic that already lives in `Shared/` and is testable from iOS. Pairing needs a real paired device; the simulator's WatchConnectivity is unreliable.

---

## W7 — Watch complications

**Now the only wrist surface**, and the truest "back of my mind" reminder — permanent, on the watch face, never expires. Owns `FastedWatchWidgets/*` (target already declared in W2).

Families `.accessoryCircular`, `.accessoryCorner`, `.accessoryRectangular`, `.accessoryInline`. The circular/rectangular/inline views are **identical** to W4's Lock Screen accessory views — reuse them from `Shared/FastProgressViews.swift`, don't duplicate.

Reads the snapshot from the watch-side App Group written by `FastedWatch` on receipt of each `updateApplicationContext`. Same `timerInterval` backbone, so the complication ticks without reload budget.

**Verify:** timeline logic reuses W4's tested `WidgetTimelineBuilder`. Face placement and rendering are device verification.

---

## W8 — Release plumbing and doc reconciliation

- `fastlane/Fastfile` calls `get_provisioning_profile` only for `com.grusy.SolsticeFast`. Add `.Widgets`, `.watchkitapp`, and `.watchkitapp.Widgets` to both `beta` and `release`.
- `Makefile`'s `build-watch` swallows failure with `|| echo "Watch scheme not built yet"` and targets a hardcoded device — make it fail loudly and use `generic/platform=watchOS Simulator`.
- `README.md` claims a watch app and Swift Charts that never existed; the watch claim becomes true, the Charts claim should go. `CONTRIBUTING.md` says CI runs "watchOS Build" — now true.
- `Fasted/Info.plist` declares `UIRequiredDeviceCapabilities: [armv7]`, stale for a 64-bit-only app and a plausible new rejection source once new targets trigger re-validation. Remove it.
- Preserve all existing `FastedUITests` accessibility identifiers (`start_fast_button`, `end_fast_button`, `elapsed_time_text`, …) — the UI tests and screenshot generator depend on them.

### Manual Apple Developer portal work — for the human, blocks TestFlight only, not CI

1. Create App Group `group.com.grusy.SolsticeFast`.
2. Enable App Groups on App ID `com.grusy.SolsticeFast` and **regenerate its provisioning profile** — the existing one predates the entitlement and will fail to sign.
3. Create App IDs `com.grusy.SolsticeFast.Widgets`, `.watchkitapp`, and `.watchkitapp.Widgets`, each with App Groups enabled, and profiles for each.
4. Supply a watchOS app icon asset.

---

## Risks most likely to make the agent fail

1. **Silent no-op `project.yml` edits** — highest-probability failure. Without W0, a `project.yml` edit goes green in CI against the *old* project, and nobody notices the extension doesn't exist. Mitigated by W0 first + W2's explicit per-scheme build steps.
2. **Hand-editing `project.pbxproj`** — tempting when xcodegen isn't available locally. Prohibited in the agent definition; after W0 there's no reason to.
3. **Always-true `#available` under warnings-as-errors** — with a uniform iOS 18 floor, availability gating for these APIs is a *build failure*, not a safety net.
4. **`Shared/` referencing Core Data** — `Fast`/`UserSettings` are codegen classes existing only in the `Fasted` target. Writing `FastSnapshot(from: Fast)` in `Shared/` breaks the widget and watch builds. All conversion lives in `Fasted/FastManager+SharedState.swift`.
5. **An intent writing Core Data directly** — it will appear to work in the simulator when the app happens to be running, then silently fail in the field when it runs in the extension. This is the single most dangerous mistake available, because it is *intermittently* correct. The rule: intents only ever enqueue.
6. **Optimistic snapshot treated as durable** — skipping the queue and writing only the snapshot from an extension loses the write forever. The invariant, stated everywhere: *the queue is the only durable channel; the snapshot is cosmetic and always overwritten by the app.*
7. **Non-atomic queue appends** — using an App Group `UserDefaults` array instead of `NSFileCoordinator` produces a rare, unreproducible lost-command bug.
8. **SwiftLint `--strict` at 120 columns** — WidgetKit generic signatures blow past it immediately. Use `typealias`; treat the lint job as the first CI signal.
9. **`force_unwrapping`** — widget sample code is full of `URL(string:)!` and `UserDefaults(suiteName:)!`. Use `??` fallbacks.
10. **Watch target inheriting iOS `SUPPORTED_PLATFORMS`** — produces a confusing "does not support the platform iOS" error that's easy to misdiagnose as a source problem. W0 removes the keys before any watch target exists.
11. **A watch compile error blocking all further work** — once `Fasted` depends on `FastedWatch`, it fails `-scheme Fasted` entirely. W2's watch placeholder is deliberately trivial, so this risk is front-loaded into one easy-to-fix commit rather than discovered later inside W6.
12. **Reintroducing Live Activities** — knowing ActivityKit exists is a pull, especially in W4. Out of scope by decision.
13. **Shipping half-built targets to TestFlight** — `deploy.yml` fires on every push to `main`. Hence the `feat/companion-surfaces` integration branch.
14. **Overclaiming verification** — no compiler exists in this environment. Every commit message must say what CI does and doesn't prove, and any newly-discovered device-only check must be added to the Verification section below, not left unrecorded.
15. **Losing track of progress across sessions** — a build this size will likely span more than one context window. Mitigated entirely by the checklist at the top of this file: check a workstream's box only once its commit is pushed, never before, so a resumed session can trust the checklist completely and never has to reconstruct state by reading git log.

---

## Verification

This section is cumulative — as each workstream is implemented, add any new device-only checks it introduces here rather than tracking them separately per commit.

**What CI proves** (after W0 adds xcodegen + per-scheme builds): SwiftLint `--strict` passes; `Fasted`, `FastedWidgets`, `FastedWatch`, and `FastedWatchWidgets` all compile warning-free; `FastedTests` and `FastedUITests` pass.

**Genuinely self-verifiable in this environment** — all of W1 (snapshot codable + schema guard, enqueue/drain/dedupe/cap, **end-timestamp == tap time**, idempotency, mismatched `targetFastID`, ordering, queue cap), W-A's scheduling logic, and the pure-logic halves of W3/W4/W6 (`FastCommandFactory`, `WidgetTimelineBuilder`, `WatchPayload`).

**Device verification required, by a human** — widget rendering across all families; StandBy legibility at night; Lock Screen accessory placement; the Control Center toggle and Action Button; watch pairing and `transferUserInfo` after relaunch; complication rendering on real faces; and every signing/provisioning outcome.

**End-to-end smoke test on a device, once W4–W7 land:**
1. Start a fast from Control Center without opening the app → widget updates; watch face complication updates.
2. Lock the phone → Lock Screen accessory shows the correct metabolic stage.
3. Put the phone on a charger in landscape overnight → StandBy shows the fast all night, still correct in the morning.
4. Force-quit the app, end the fast from the widget past goal → open the app → History shows the fast ending at the **tap** time, not the launch time.
5. Start a fast on the watch with the phone in another room → phone reflects it on next foreground with the correct start time.
6. Cross a stage boundary (e.g. hour 12) with the app closed → stage-transition notification fires and the widget's stage label updates.
