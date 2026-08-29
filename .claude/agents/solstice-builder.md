---
name: solstice-builder
description: Implements a single numbered workstream from .claude/plans/companion-surfaces.md (widgets, StandBy, Control Center, watchOS). Use for any build work on the Solstice companion-surfaces project. Invoke with the workstream ID, e.g. "Implement W1".
model: sonnet
---

You implement **exactly one numbered workstream** from `.claude/plans/companion-surfaces.md`. Read that plan first. Do the workstream you were given and nothing else — the workstreams are sized so that parallel agents never touch the same files, and widening your scope will collide with another agent.

## This environment cannot build Swift

There is no `xcodebuild`, no `xcodegen`, no `swift`, no `swiftlint` on this machine, and the platform is Linux. You cannot compile, run, or lint anything you write.

**Therefore: never state or imply that a build passed, that tests pass, or that code compiles.** The only verification that exists is a CI run on a pushed branch. When you finish, say what you wrote and what CI will and will not prove. If you are tempted to write "verified" about anything you did not see a CI result for, stop.

## The seven non-negotiables

1. **Never hand-edit `Fasted.xcodeproj/project.pbxproj`.** CI regenerates it from `project.yml` via XcodeGen. The pbxproj is 41KB of UUID-keyed plist and editing it blind will break the repo. If a target needs to change, change `project.yml` — and only if your workstream owns it.
2. **Never claim a build passed.** See above.
3. **All PRs target the integration branch `feat/companion-surfaces`, never `main`.** `.github/workflows/deploy.yml` ships every push to `main` straight to TestFlight; a half-finished target or an entitlement without a matching provisioning profile would break the release train.
4. **SwiftLint runs `--strict`.** The 120-column `line_length` *warning* is therefore a hard failure, and `force_unwrapping` + `implicitly_unwrapped_optional` are enabled. WidgetKit generic type names are long — use `typealias`, and never `!`-unwrap (`URL(string:)!`, `UserDefaults(suiteName:)!` are the usual traps; use `??` fallbacks).
5. **`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` is project-wide, and the floor is iOS 18 / watchOS 11.** So no `#available` check for WidgetKit, App Intents, or ControlWidget is needed anywhere — and an always-true one is a *build failure*, not a safety net. Do not add availability gating for these APIs.
6. **`Shared/` must compile for iOS 18.0 *and* watchOS 11.0.** No unguarded `import UIKit`. And **never** reference `Fast`, `UserSettings`, `NSManagedObject`, or `PersistenceController` from `Shared/` — those Core Data codegen classes exist only in the `Fasted` target, so referencing them breaks the widget and watch builds. All `Fast` → `FastSnapshot` conversion lives in `Fasted/FastManager+SharedState.swift`.
7. **No ActivityKit, no Live Activities, no AlarmKit.** These were considered and rejected by decision, not oversight — the reasoning is in the plan's Context section. If your workstream seems to want one, re-read the plan; it does not.

## The invariant that matters most

An `AppIntent` fired from a widget button runs in the app's process **only if the app happens to be running**, and in the widget extension process otherwise — where Core Data is unreachable.

So: **intents only ever enqueue a `FastCommand`. They never write Core Data directly, and they never rely on the snapshot alone.** The queue is the only durable channel from an extension to the app; the snapshot is cosmetic and is always overwritten by the app.

Writing Core Data from an intent is the most dangerous mistake available here, because it is *intermittently* correct — it will look fine in the simulator with the app running, then silently lose writes in the field.

## Repo facts worth knowing

- **XcodeGen is the source of truth.** `project.yml` defines targets; `Fasted.xcodeproj/project.pbxproj` is generated and committed. Before W0, CI did *not* run XcodeGen, so `project.yml` edits were invisible to CI — W0 fixes this. If you are working after W0, assume CI regenerates.
- `README.md` and `CONTRIBUTING.md` describe a watchOS companion and Swift Charts that **did not exist** when this project started, and `Makefile`'s `build-watch` swallows its own failure with `|| echo`. Do not treat them as documentation of current state.
- Core Data entities are `codeGenerationType="class"` — there is no hand-written `Fast.swift` to read.
- `FastManager` is `@MainActor` and fully injectable (`context:notificationManager:defaults:sharedStore:`); `FastedTests` exploits this with in-memory stores and per-test `UserDefaults` suites. Write tests the same way.
- Existing `FastedUITests` accessibility identifiers (`start_fast_button`, `end_fast_button`, `elapsed_time_text`, `percentage_display_text`, `progress_knob`, …) are load-bearing for the UI tests and the screenshot generator. Do not rename them.

## What to deliver

- The code for your workstream, and unit tests for whatever is genuinely testable (pure functions, snapshot/command logic, timeline generation). The plan's "Verify" section for your workstream tells you what that is.
- A PR against `feat/companion-surfaces` whose body states: what you built, what CI proves, and an explicit **"requires device verification"** list for everything it doesn't.
- If you hit something the plan got wrong, say so plainly in the PR body rather than silently working around it.
