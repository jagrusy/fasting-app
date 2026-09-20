# What testing means here

Choose evidence for the failure that the change could cause. Do not demand every expensive check for a text edit or claim an emulator proves sensor hardware behavior.

| Change | Minimum relevant evidence |
| --- | --- |
| Documentation/research | Valid references, explicit assumptions, correct commands/paths, reproducible arithmetic |
| State/persistence | Unit transitions plus failed reads/writes, disk-backed reopening/upgrade, no duplicate/lost effects |
| App flow | Deterministic initial state, unconditional outcome assertions, persisted relaunch, relevant permission denial |
| Shared command/Watch | Contract compatibility, duplicate/stale/offline/reconnect cases, all target builds, physical smoke for transport claims |
| Design | Light/dark, large text, VoiceOver order, reduced motion, non-color state cues |
| CI/release | Decision matrix with failure cases, YAML/action validation, exact commit identity, secrets boundary and live protection evidence |
| Health/sensors/payments | Mocked failures plus actual supported device or sandbox/TestFlight behavior; explicitly pending checks remain open |

## Current local commands

Inspect current `project.yml` and `Makefile` before running. Record `xcodebuild -version`, XcodeGen and SwiftLint versions. Generate the project with `xcodegen generate`; do not stage incidental output from unrelated work.

Discover a simulator with `xcrun simctl list devices available -j` and select an explicit model/OS/UDID. Replace placeholders below; use fresh result paths per run:

```sh
xcodebuild test -project Fasted.xcodeproj -scheme FastedTests \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -resultBundlePath '<fresh-artifact-directory>/unit.xcresult'
xcodebuild test -project Fasted.xcodeproj -scheme FastedUITests \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -resultBundlePath '<fresh-artifact-directory>/ui.xcresult'
swiftlint lint --strict
```

Use focused test selection while iterating, then the required affected suite before handoff. Build affected Watch schemes with `generic/platform=watchOS Simulator` and iOS schemes with the declared iOS simulator. A Watch compile is not a transport/hardware test.

Known limitations until the tooling ticket lands: `make all` omits UI tests, `make lint` silently skips a missing tool, and repeated `make test`/`make uitest` can fail on existing xcresult paths. Do not cite those shortcuts as full validation.

## Evidence and release decisions

Record base/head commits; commands and exit status; OS/tool/device versions; artifact locations; first failures; changed-behavior assertions; unavailable checks. Repeat tests to investigate a specific flake or new change, not to erase the first result. Gate high-risk work on relevant failures being resolved.

Physical acceptance requires a named device/tester and observed result. Sensor and transport claims require the actual supported hardware. Preserve raw records through an upgrade and verify all four signed bundles before release. A corrective App Store update is generally the recovery path; do not promise an instant binary rollback.
