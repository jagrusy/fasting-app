# Contributing to Fasted

This document outlines conventions and guidelines for human contributors and remote autonomous coding agents.

## Development Workflow

1. **Pick an Issue**: Check Linear for active tasks (e.g. `GRU-6`).
2. **Create a Feature Branch**:
   - Format: `feat/<feature-name>` (e.g., `feat/core-data-stack`)
   - Bug fixes: `fix/<issue-name>`
   - Refactor / Polish: `refactor/<name>` or `chore/<name>`
3. **Develop & Test Locally**:
   - Write unit tests alongside your code under `FastedTests/`.
   - Run `make test` before submitting changes.
   - Run `make lint` to verify adherence to style rules.
4. **Open a Pull Request**:
   - Ensure PR description clearly references the Linear issue identifier (e.g. `Closes GRU-6`).
   - GitHub Actions CI must pass 100% (Lint, iOS Build, watchOS Build, Unit Tests).

## Testing Standards

- **Unit Tests (`FastedTests`)**: Required for all business logic, date calculations, duration helpers, circular angle calculations, and Core Data migrations/stores.
- **UI Tests (`FastedUITests`)**: Reserved for critical navigation and state transitions. Keep them resilient and deterministic.

## Warnings as Errors
All builds enforce `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. Ensure clean compiles without deprecation or unhandled warnings.
