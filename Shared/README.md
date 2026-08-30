# Shared Module

This directory contains pure Swift / SwiftUI models, themes, and logic that are shared across all targets in the Fasted workspace:
- Main iOS App (Fasted)
- Home / Lock Screen / StandBy Widgets (FastedWidgets)
- Control Center Controls (FastedControlCenter)
- watchOS Companion App (FastedWatch)
- Watch Complications (FastedWatchComplications)
- Unit and UI Test Suites

## Cross-Platform Invariants

1. Deployment Targets: Must compile cleanly for both iOS 18.0 and watchOS 11.0.
2. No Core Data: Do NOT import CoreData or reference Core Data managed object classes (Fast, UserSettings, PersistenceController, NSManagedObject). Shared state communication uses lightweight Codable value types (e.g. FastingStateSnapshot) and AppGroupCoordinator.
3. No Unguarded UIKit: Avoid UIKit where SwiftUI equivalents exist (Color, Image, etc.). Any platform-specific code (e.g., haptics or UIApplication) must be guarded with #if canImport(UIKit) && !os(watchOS).
4. Pure Value Types: Prefer struct and enum types conforming to Sendable, Codable, Identifiable, and Equatable.
5. No ActivityKit: Live Activities are intentionally excluded due to Apple 12-hour limit.
