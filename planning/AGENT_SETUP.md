# One guide for Codex, Claude, Gemini and Antigravity

The root `AGENTS.md` is canonical. Root `CLAUDE.md` and `GEMINI.md` are relative symlinks to `AGENTS.md`, so changes cannot drift between copies. Edit `AGENTS.md`; preserve both links. Scoped guides add local invariants, and the root guide directs every agent to read the applicable ones before editing.

- Codex: start in the intended worktree; read the discovered root guide and explicitly read applicable scoped guides before edits. [Official discovery documentation](https://developers.openai.com/codex/guides/agents-md).
- Claude Code: `CLAUDE.md` resolves to the root guide. Check `/context` for loaded memory files and ask the agent to name the applicable scoped guides. [Official memory documentation](https://code.claude.com/docs/en/memory).
- Gemini CLI: `GEMINI.md` resolves to the same root guide. Use `/memory reload`, then `/memory show`, to inspect loaded context; explicitly read the scoped `AGENTS.md` files named by the root guide. [Official context documentation](https://geminicli.com/docs/cli/gemini-md/).
- Antigravity: `.agent/rules/repository.md` is a thin compatible rule adapter. Current docs default to `.agents/rules` and retain `.agent/rules` compatibility; check the installed IDE's Rules view and explicitly activate this rule if needed. Do not change global rules or permissions. [Official rule documentation](https://antigravity.google/docs/rules-workflows).

Both relative symlinks have been checked locally for identical resolved content. Codex's root guide was loaded in this task; Claude/Gemini/Antigravity automatic loading has not been exercised here. Check each installed client rather than treating a filesystem check as proof of its loader behavior. If a checkout materializes symlinks as plain text, restore symlink support before relying on automatic loading. Use this explicit startup prompt when uncertain:

> Read the repository's AGENTS.md, planning/TESTING.md, the issue and its prerequisites, then all scoped AGENTS.md files for the paths you will change. State your base SHA, owned paths, prerequisite evidence and validation plan before editing. Work only on this issue in an isolated branch/worktree. Preserve unrelated work and report checks actually run using planning/agent-handoffs/TEMPLATE.md.

Instructions guide agents; they do not replace GitHub protection, protected credentials, or independent review. Do not enable broader automatic actions based solely on successful instruction loading.
