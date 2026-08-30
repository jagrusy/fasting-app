import Foundation
import WatchConnectivity

public final class WatchSessionManager: NSObject, WCSessionDelegate {
    public static let shared = WatchSessionManager()

    private override init() {
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    public func syncSnapshotToWatch(_ snapshot: FastingStateSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let payload = WatchPayload.encodeSnapshot(snapshot) else { return }

        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Context update may fail if session is suspended; will catch up on next sync
        }
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            let snapshot = AppGroupCoordinator.shared.readSnapshot()
            syncSnapshotToWatch(snapshot)
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingDictionary(message)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncomingDictionary(userInfo)
    }

    private func handleIncomingDictionary(_ dict: [String: Any]) {
        guard let envelope = WatchPayload.decodeCommand(from: dict) else { return }
        AppGroupCoordinator.shared.enqueueEnvelope(envelope)
    }
}
