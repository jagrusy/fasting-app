# Native state and persistence

- Preserve `Fasted`'s Core Data model/store identity, record UUIDs, timestamps, original goals, protocol, mood/completion, settings/schedule data and per-fast snooze defaults. Moving model resources can change discovery; test opening existing stores explicitly.
- A mutation is successful only after persistence commits. Failed saves/fetches need explicit errors and controlled rollback; snapshots, notifications and review prompts must reflect committed state.
- Inject clocks and failure-prone dependencies where the tested behavior needs control. Use real temporary disk stores for persistence/relaunch/upgrade evidence, not only in-memory mocks.
- `ContentView` currently owns manager lifetime and foreground reconciliation. Do not remove that lifecycle behavior incidentally during UI changes.
- Destructive fixtures must use isolated test storage and be unavailable in production builds. Never erase actual data to seed screenshots.
- Read `Shared/AGENTS.md` before changing command, snapshot or Watch coordination.
