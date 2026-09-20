# Working on Solstice / Fasted

## Product and architecture

- Preserve the existing SwiftUI app, native widgets/Watch, Core Data store, bundle identifiers and App Group. Platform expansion, database migration and new paid features require the recorded owner decision in the issue.
- Read the assigned issue and its linked strategy/audit documents in the authorized tracker. Recheck historical findings against current code. Keep private planning and complete ticket exports outside this public repository; include only necessary engineering context in commits.
- `project.yml` is the XcodeGen source of truth. Do not hand-edit generated project settings. Keep the existing six scheme names stable.
- Core Data is the authoritative iOS history writer. External actions require durable application/acknowledgment; UI optimism is not persisted success. Do not reset user data to recover from an error.

## Claim and isolate work

- Read the issue, blockers, current root guide and scoped guides before edits. Record the issue, base SHA, branch, owned paths and validation plan in Linear or a local handoff if Linear is unavailable.
- Use one branch/worktree per issue; Codex uses `codex/<issue>-<slug>`. Preserve unrelated changes, including website/marketing drafts. Never stage the whole dirty owner checkout.
- Prerequisites must be merged into the base, not merely labeled Done. Stacked local preparation is allowed when explicitly identified, but do not claim a dependent issue complete before its required base/review is ready.
- At most two code implementations plus a research/review lane. One writer at a time owns a persistent model, wire contract, `project.yml`, root dependency/toolchain config or release workflow. Worktrees do not prevent semantic conflicts: coordinate a needed shared-file edit before making it.
- Before Watch/shared-state changes, reconcile historical tracker issues with current code and active work. Do not silently close old issues or implement competing versions.

## Verification and review

- Follow [testing guidance](planning/TESTING.md), relevant scoped guidance, and issue-specific acceptance criteria. A missing control must fail its UI test; a skipped branch is not success.
- Report the exact commands, toolchain, simulator/device, result paths, first failures and unresolved checks. No unmeasured speedup, invented device evidence, or blanket retry that hides a failure.
- Data/contracts, health, payments, permissions, CI, signing and policy changes require independent review. Agent prose is not enforcement: do not enable auto-merge until trusted checks and identity restrictions are verified.
- User authorization governs external actions. An implementation issue alone does not authorize production publication, spending, outreach, permission expansion or source-visibility changes. Keep existing free-core promises.
- Finish with the [handoff template](planning/agent-handoffs/TEMPLATE.md). Preserve symbols/artifacts needed for recovery. Never commit credentials, signing profiles, personal stores or unredacted health records.

## Navigation

- Native state/persistence: `Fasted/AGENTS.md`.
- Shared commands and extensions: `Shared/AGENTS.md`; also read it for Watch changes.
- Unit/UI tests: `FastedTests/AGENTS.md`, `FastedUITests/AGENTS.md`.
- Release/build automation: `.github/AGENTS.md`; also read it for `fastlane/` and release scripts.
- Agent loading and explicit fallback prompt: [setup](planning/AGENT_SETUP.md).
