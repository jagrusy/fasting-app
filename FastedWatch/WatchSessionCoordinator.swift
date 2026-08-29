import Foundation
import SwiftUI
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WatchSessionCoordinator: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionCoordinator()

    @Published var snapshot: FastingStateSnapshot

    private override init() {
        self.snapshot = AppGroupCoordinator.shared.readSnapshot()
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func startFast(
        startDate: Date = Date(),
        duration: TimeInterval = 16 * 3600,
        protocolType: String = "16:8"
    ) {
        let command = FastingActionCommand.startFast(
            startDate: startDate,
            duration: duration,
            protocolType: protocolType
        )
        let envelope = PendingCommandEnvelope(command: command)
        sendCommandToPhone(envelope)

        let optimistic = snapshot.startingNow(
            startDate: startDate,
            duration: duration,
            protocolType: protocolType
        )
        updateLocalSnapshot(optimistic)
    }

    func endFast(endDate: Date = Date()) {
        let command = FastingActionCommand.endFast(endDate: endDate)
        let envelope = PendingCommandEnvelope(command: command)
        sendCommandToPhone(envelope)

        let optimistic = snapshot.endingNow(at: endDate)
        updateLocalSnapshot(optimistic)
    }

    private func sendCommandToPhone(_ envelope: PendingCommandEnvelope) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let payload = WatchPayload.encodeCommand(envelope) else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                session.transferUserInfo(payload)
            })
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func updateLocalSnapshot(_ newSnapshot: FastingStateSnapshot) {
        self.snapshot = newSnapshot
        AppGroupCoordinator.shared.writeSnapshot(newSnapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let incoming = WatchPayload.decodeSnapshot(from: applicationContext) else { return }
        Task { @MainActor in
            self.updateLocalSnapshot(incoming)
        }
    }
}
