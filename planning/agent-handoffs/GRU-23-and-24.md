# Shared agent guidance and release-policy preparation

- Issues: GRU-23 (repository guidance), GRU-24 (release admission). Stacked preparation; neither issue is Done or merged.
- Branch: `codex/gru-24-release-guardrails`.
- Base: `2f7b44b0a3af2e2ad716d6b95204e5e310e7efd1` (current main when prepared).
- Ownership: canonical/scoped agent guides and adapters; engineering setup/testing/handoff guides; CI completion contract; deploy workflow; release policy/tests; Fastlane entry guards; deployment documentation; obsolete Makefile upload comment. No native app code, project settings, screenshots or website changes.

## Behavior

`AGENTS.md` is canonical; root `CLAUDE.md` and `GEMINI.md` are relative symlinks to it. Scoped guides and a thin Antigravity adapter preserve one policy source. Client inspection commands and an explicit startup prompt are documented. Private planning and tracker exports remain outside the public repository.

Distribution checks the exact current-main source SHA against the latest successful main-push CI run and its current attempt, including every required job. Main/tag/PR identity, manual operator, skipped/failed/cancelled checks and reused production approval are checked explicitly. Publishing is serialized per app, direct local upload bypasses fail, and temporary signing material is cleaned up.

Both preflight and pre-signing checks require the selected `testflight` or `production` environment to allow exactly one branch rule: `main`. Unrestricted settings, protected-branch fallback, tags, wildcard/extra rules, absent identity and unreadable settings fail closed. Production additionally requires configured human review and actual allowlisted human approval; automatic beta does not require production configuration. Credentials must be environment-scoped, with repository/organization copies removed by the owner.

## Verification

- Local tools: macOS 26.5.2 (25F84), Python 3.9.9, Ruby 3.4.8 (arm64-darwin25), Actionlint 1.7.12.
- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v`: 35 passed, including environment failure cases and end-to-end preflight fixtures. Rejected preflight produces no publishing-job outputs.
- `ruby fastlane/tests/release_guard_test.rb`: 5 tests / 7 assertions passed.
- `ruby -c fastlane/Fastfile`: syntax OK.
- Actionlint 1.7.12 on `.github/workflows/ci.yml` and `deploy.yml`: passed. Tool archive was checksum-verified during preparation.
- Both symlinks (`CLAUDE.md`, `GEMINI.md`) and `agent.md` resolve to exactly `AGENTS.md`; Git records mode `120000`. Local guide links and diff whitespace checks pass. Pre-commit SwiftLint passed (0 violations across 99 files).
- Merged `origin/main` (commit `c56594c`) resolving conflicts in `deploy.yml` to support automated version resolution (`resolve_version.sh`), optional manual `version_override`, and git build tagging with permissions while maintaining the release admission gate.
- Configured XcodeGen `options.fileTypes.md.buildPhase: none` in `project.yml` to prevent duplicate resource copy collisions for scoped `AGENTS.md` files while keeping them visible in Xcode.
- Native builds verified: `Fasted` (iOS), `FastedWidgets` (iOS Widget Extension), `FastedWatch` (watchOS), and `FastedWatchWidgets` (watchOS Widget Extension) compiled cleanly with warnings-as-errors.
- Native test suite verified: 132/132 unit tests (`FastedTests`) and 15/15 UI tests (`FastedUITests`) passed on iOS 26.1 Simulator.

## Acceptance and remaining gates

| Item | Result |
| --- | --- |
| Canonical/scoped instructions, shared Claude/Gemini links, explicit invocation fallback | Pass locally |
| Codex root guide loaded in this task | Pass |
| Claude/Gemini/Antigravity automatic loading in their installed clients | Not run; explicit fallback documented |
| Exact source/CI identity and accepted/rejected decision fixtures | Pass locally |
| Selected environment restricted to the main branch | Pass with fixtures; live configuration missing |
| Configured/actual human production approval | Pass with fixtures; successful hosted admission not run |
| Credential placement, removal of repo/org copies, disabled administrator bypass | Owner configuration/evidence required; not asserted by this script |
| Identified tested binary promoted without rebuilding | Not implemented; separate artifact-promotion issue |
| Hosted CI, signed archive, TestFlight smoke, production submission/publication | Not run |
| Required main-branch checks and approving PR review | Live controls absent; do not enable auto-merge |

Read-only GitHub inspection on 20 September 2026 found only the `github-pages` environment. Classic main protection was absent. The active ruleset protected deletion/non-fast-forward changes and configured Copilot review, but required neither CI checks nor approving PR review. No remote settings were modified.

The release lane still rebuilds after source approval. Exact SHA verification is not proof of tested binary identity, and this issue must not be marked fully accepted on that basis. No push, PR, merge, signed build, upload or release has been performed for this preparation. Review the local branch, configure and verify external controls through the owner, and complete binary promotion before claiming the complete release contract.
