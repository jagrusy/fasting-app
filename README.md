# Fasted

A minimal, native intermittent fasting tracker for iOS (16+) and watchOS (9+), built with SwiftUI, Core Data, and Swift Charts.

## Key Features
- **No Paywall / Pure Utility**: Simple, distraction-free fasting tracking.
- **Alarm-Style Circular Dial Editor**: Drag start/end points or shift entire fasting windows intuitively (inspired by iOS Clock / Bedtime).
- **Core Data Local-First**: Privacy-first storage without requiring cloud accounts.
- **Trends & Heatmaps**: Swift Charts + Calendar contribution view.
- **Apple Watch Companion**: Track, start, and end fasts directly on your wrist with complications and actionable notifications.

## Project Structure
- `Fasted/`: iOS Main Application (SwiftUI + Core Data)
- `FastedWatch/`: watchOS Companion App (SwiftUI + WatchConnectivity)
- `FastedTests/`: Unit tests (Logic, Math, Conversions, Data models)
- `FastedUITests/`: UI tests for critical user journeys

## Developer Quickstart

```bash
# Run unit tests in iOS Simulator
make test

# Run UI tests
make uitest

# Lint Swift code
make lint

# Build all targets (iOS + watchOS)
make build
```

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for branch naming conventions, workflow guidelines, and CI standards for both human contributors and autonomous agents.
