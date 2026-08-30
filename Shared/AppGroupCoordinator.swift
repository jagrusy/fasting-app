import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class AppGroupCoordinator: @unchecked Sendable {
    public static let defaultAppGroupId = "group.com.grusy.SolsticeFast"
    public static let shared = AppGroupCoordinator()

    private let userDefaults: UserDefaults
    private let appGroupId: String
    private let lock = NSLock()

    /// False when the App Group container could not be opened and this instance fell back to a
    /// process-local `UserDefaults`.
    ///
    /// Worth checking, because the fallback fails *silently and convincingly*: an extension writes
    /// its optimistic snapshot, reads it straight back, and renders correctly — while the app never
    /// sees a single command. If the App Group entitlement or provisioning profile is wrong, this
    /// is the only signal that anything is amiss.
    public let isUsingSharedContainer: Bool

    public static let snapshotKey = "fasting_state_snapshot"
    public static let pendingCommandsKey = "pending_fasting_commands"

    public init(userDefaults: UserDefaults? = nil, appGroupId: String = defaultAppGroupId) {
        self.appGroupId = appGroupId
        if let defaults = userDefaults {
            self.userDefaults = defaults
            self.isUsingSharedContainer = true
        } else if let groupDefaults = UserDefaults(suiteName: appGroupId) {
            self.userDefaults = groupDefaults
            self.isUsingSharedContainer = true
        } else {
            self.userDefaults = .standard
            self.isUsingSharedContainer = false
            NSLog("[Solstice] App Group \(appGroupId) unavailable — widget and watch commands "
                + "will not reach the app. Check the App Group entitlement and provisioning profile.")
        }
    }

    public func writeSnapshot(_ snapshot: FastingStateSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        if let encoded = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(encoded, forKey: Self.snapshotKey)
        }
        notifyWidgetsOfUpdate()
        DarwinNotificationCenter.shared.post()
    }

    public func readSnapshot() -> FastingStateSnapshot {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(FastingStateSnapshot.self, from: data) else {
            return .idle
        }
        return snapshot
    }

    public func enqueueCommand(_ command: FastingActionCommand) {
        let envelope = PendingCommandEnvelope(command: command)
        enqueueEnvelope(envelope)
    }

    public func enqueueEnvelope(_ envelope: PendingCommandEnvelope) {
        lock.lock()
        defer { lock.unlock() }

        var commands: [PendingCommandEnvelope] = []
        if let data = userDefaults.data(forKey: Self.pendingCommandsKey),
           let existing = try? JSONDecoder().decode([PendingCommandEnvelope].self, from: data) {
            commands = existing
        }

        commands.append(envelope)

        if let encoded = try? JSONEncoder().encode(commands) {
            userDefaults.set(encoded, forKey: Self.pendingCommandsKey)
        }
        DarwinNotificationCenter.shared.post()
    }

    public func drainPendingCommands() -> [PendingCommandEnvelope] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: Self.pendingCommandsKey),
              let commands = try? JSONDecoder().decode([PendingCommandEnvelope].self, from: data) else {
            return []
        }
        userDefaults.removeObject(forKey: Self.pendingCommandsKey)
        return commands
    }

    public func notifyWidgetsOfUpdate() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
