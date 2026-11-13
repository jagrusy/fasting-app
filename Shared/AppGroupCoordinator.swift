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
    public static let pendingDeepLinkKey = "pending_deep_link"
    public static let processedCommandIdsKey = "processed_fasting_command_ids"
    private static let maxProcessedCommandIds = 200

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
            // Only reachable when the suite defaults or the container is missing, so neither half
            // of the shared setup can be trusted — including the case where the container exists
            // but `UserDefaults(suiteName:)` handed back nil and reads fall through to `.standard`.
            self.userDefaults = UserDefaults(suiteName: appGroupId) ?? .standard
            self.isUsingSharedContainer = false
            NSLog("[Solstice] App Group \(appGroupId) unavailable — widget and watch commands "
                + "will not reach the app. Check the App Group entitlement and provisioning profile.")
        }
    }

    public func writeSnapshot(_ snapshot: FastingStateSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        let previous: FastingStateSnapshot? = {
            guard let data = userDefaults.data(forKey: Self.snapshotKey) else { return nil }
            return try? JSONDecoder().decode(FastingStateSnapshot.self, from: data)
        }()

        if let encoded = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(encoded, forKey: Self.snapshotKey)
        }

        let contentChanged = previous.map { !$0.isContentEquivalent(to: snapshot) } ?? true
        if contentChanged {
            notifyWidgetsOfUpdate()
            DarwinNotificationCenter.shared.post()
        }
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

    /// Requests a tab switch the next time the app comes to the foreground.
    ///
    /// Control Center intents can foreground the app via `openAppWhenRun`, but that flag carries no
    /// destination and offers no reliable guarantee about exactly when `perform()` runs relative to
    /// the view hierarchy coming up. Relaying through the App Group instead reuses the same
    /// foreground-drain point `processPendingCommands` already relies on, so there is no race to
    /// reason about.
    public func writePendingDeepLink(_ link: DeepLink) {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.set(link.rawValue, forKey: Self.pendingDeepLinkKey)
    }

    public func consumePendingDeepLink() -> DeepLink? {
        lock.lock()
        defer { lock.unlock() }
        guard let raw = userDefaults.string(forKey: Self.pendingDeepLinkKey) else { return nil }
        userDefaults.removeObject(forKey: Self.pendingDeepLinkKey)
        return DeepLink(rawValue: raw)
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

        var processedIds = userDefaults.stringArray(forKey: Self.processedCommandIdsKey) ?? []
        var seenSet = Set(processedIds)
        var processedChanged = false
        var envelopes: [PendingCommandEnvelope] = []

        func accept(_ envelope: PendingCommandEnvelope) {
            let idString = envelope.id.uuidString
            guard !seenSet.contains(idString) else { return }
            seenSet.insert(idString)
            processedIds.append(idString)
            processedChanged = true
            envelopes.append(envelope)
        }

        drainCommandFiles(accept: accept)
        drainLegacyUserDefaultsCommands(accept: accept)

        if processedChanged {
            if processedIds.count > Self.maxProcessedCommandIds {
                processedIds = Array(processedIds.suffix(Self.maxProcessedCommandIds))
            }
            userDefaults.set(processedIds, forKey: Self.processedCommandIdsKey)
        }

        return envelopes.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func drainCommandFiles(accept: (PendingCommandEnvelope) -> Void) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: commandsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        for url in fileURLs where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url) else {
                // Unreadable now rather than invalid — most likely data protection while the
                // device is locked. Leave it queued so the next drain can pick it up.
                continue
            }
            guard let envelope = try? JSONDecoder().decode(PendingCommandEnvelope.self, from: data) else {
                quarantine(url)
                continue
            }
            accept(envelope)
            try? fileManager.removeItem(at: url)
        }
    }

    private func drainLegacyUserDefaultsCommands(accept: (PendingCommandEnvelope) -> Void) {
        if let data = userDefaults.data(forKey: Self.pendingCommandsKey),
           let legacyCommands = try? JSONDecoder().decode([PendingCommandEnvelope].self, from: data) {
            for envelope in legacyCommands {
                accept(envelope)
            }
            userDefaults.removeObject(forKey: Self.pendingCommandsKey)
        }
    }

    public func clearPendingCommands() {
        lock.lock()
        defer { lock.unlock() }

        if let fileURLs = try? fileManager.contentsOfDirectory(
            at: commandsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in fileURLs where url.pathExtension == "json" {
                try? fileManager.removeItem(at: url)
            }
        }
        userDefaults.removeObject(forKey: Self.pendingCommandsKey)
    }

    /// Moves a malformed command out of the queue without destroying it.
    ///
    /// Deleting outright discards the only record of a tap the user made, while leaving it in place
    /// makes it a poison pill re-read on every drain. The renamed file no longer matches the `json`
    /// filter, so it stays available for diagnosis without being reprocessed.
    private func quarantine(_ url: URL) {
        let destination = url.appendingPathExtension("quarantined")
        try? fileManager.removeItem(at: destination)
        do {
            try fileManager.moveItem(at: url, to: destination)
            NSLog("[Solstice] Quarantined undecodable pending command \(url.lastPathComponent)")
        } catch {
            NSLog("[Solstice] Could not quarantine \(url.lastPathComponent), discarding: \(error)")
            try? fileManager.removeItem(at: url)
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
        #if os(iOS)
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        #endif
        #endif
    }
}
