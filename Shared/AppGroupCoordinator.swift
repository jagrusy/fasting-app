import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class AppGroupCoordinator: @unchecked Sendable {
    public static let defaultAppGroupId = "group.com.grusy.SolsticeFast"
    public static let shared = AppGroupCoordinator()

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let appGroupId: String
    private let commandsDirectory: URL
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

    public init(
        userDefaults: UserDefaults? = nil,
        fileManager: FileManager = .default,
        appGroupId: String = defaultAppGroupId,
        commandsDirectory: URL? = nil
    ) {
        self.appGroupId = appGroupId
        self.fileManager = fileManager

        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        if let explicitDir = commandsDirectory {
            self.commandsDirectory = explicitDir
        } else if let container = containerURL {
            self.commandsDirectory = container.appendingPathComponent("pending_commands", isDirectory: true)
        } else {
            self.commandsDirectory = fileManager.temporaryDirectory
                .appendingPathComponent(appGroupId, isDirectory: true)
                .appendingPathComponent("pending_commands", isDirectory: true)
        }

        if let defaults = userDefaults {
            self.userDefaults = defaults
            self.isUsingSharedContainer = true
        } else if let groupDefaults = UserDefaults(suiteName: appGroupId), containerURL != nil {
            self.userDefaults = groupDefaults
            self.isUsingSharedContainer = true
        } else {
            self.userDefaults = UserDefaults(suiteName: appGroupId) ?? .standard
            self.isUsingSharedContainer = containerURL != nil
            if containerURL == nil {
                NSLog("[Solstice] App Group \(appGroupId) unavailable — widget and watch commands "
                    + "will not reach the app. Check the App Group entitlement and provisioning profile.")
            }
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

        ensureCommandsDirectoryExists()

        let timestampStr = String(format: "%.6f", envelope.timestamp.timeIntervalSince1970)
        let filename = "\(timestampStr)_\(envelope.id.uuidString).json"
        let fileURL = commandsDirectory.appendingPathComponent(filename)

        if let encoded = try? JSONEncoder().encode(envelope) {
            do {
                try encoded.write(to: fileURL, options: .atomic)
            } catch {
                NSLog("[Solstice] Failed to write pending command envelope: \(error)")
            }
        }
        DarwinNotificationCenter.shared.post()
    }

    public func drainPendingCommands() -> [PendingCommandEnvelope] {
        lock.lock()
        defer { lock.unlock() }

        var envelopes: [PendingCommandEnvelope] = []

        if let fileURLs = try? fileManager.contentsOfDirectory(
            at: commandsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            for url in jsonFiles {
                if let data = try? Data(contentsOf: url),
                   let envelope = try? JSONDecoder().decode(PendingCommandEnvelope.self, from: data) {
                    envelopes.append(envelope)
                }
                try? fileManager.removeItem(at: url)
            }
        }

        // Drain any legacy commands stored in UserDefaults for backward compatibility
        if let data = userDefaults.data(forKey: Self.pendingCommandsKey),
           let legacyCommands = try? JSONDecoder().decode([PendingCommandEnvelope].self, from: data) {
            envelopes.append(contentsOf: legacyCommands)
            userDefaults.removeObject(forKey: Self.pendingCommandsKey)
        }

        return envelopes.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func ensureCommandsDirectoryExists() {
        if !fileManager.fileExists(atPath: commandsDirectory.path) {
            try? fileManager.createDirectory(at: commandsDirectory, withIntermediateDirectories: true)
        }
    }

    public func notifyWidgetsOfUpdate() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
