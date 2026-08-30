# Fasted (Solstice Fast)

A minimal, native intermittent fasting tracker for iOS (18+) and watchOS (11+), built with SwiftUI, Core Data, WidgetKit, and App Intents.

## Key Features
- **No Paywall / Pure Utility**: Simple, distraction-free fasting tracking.
- **Alarm-Style Circular Dial Editor**: Drag start/end points or shift entire fasting windows intuitively (inspired by iOS Clock / Bedtime).
- **Core Data Local-First**: Privacy-first storage without requiring cloud accounts.
- **Interactive Widgets & StandBy**: Home Screen, Lock Screen, and StandBy widgets displaying live timer intervals and metabolic stage transitions without battery drain.
- **Control Center Control**: Toggle fasts instantly from Control Center, Lock Screen control slots, or the Action Button.
- **Apple Watch Companion & Complications**: Start/end fasts on your wrist and view live progress on any watch face complication.
- **Actionable Notifications**: Notification reminders with quick-start actions and metabolic stage milestone alerts.

## Project Structure
- `Shared/`: Platform-agnostic domain logic, snapshots, App Intents, and progress views
- `Fasted/`: iOS Main Application (SwiftUI + Core Data + WatchConnectivity)
- `FastedWidgets/`: iOS WidgetKit Extension (Home/Lock Screen widgets & Control Center controls)
- `FastedWatch/`: watchOS Companion App (SwiftUI + WatchConnectivity)
- `FastedWatchWidgets/`: watchOS Complication Extension (Accessory circular, corner, inline, rectangular)
- `FastedTests/`: Unit tests (Snapshot logic, timeline builders, App Intents, conversion, data models)
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
