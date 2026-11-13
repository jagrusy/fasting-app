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
    private var darwinObserverToken: DarwinNotificationCenter.ObserverToken?

    private override init() {
        self.snapshot = AppGroupCoordinator.shared.readSnapshot()
        super.init()
        self.darwinObserverToken = DarwinNotificationCenter.shared.observe { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshFromLocalStore()
            }
        }
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func startFast(
        startDate: Date = Date(),
        duration: TimeInterval = FastingProtocol.default.fastingSeconds,
        protocolType: String = FastingProtocol.default.ratioString
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

    func discardFast() {
        let envelope = PendingCommandEnvelope(command: .discardFast)
        sendCommandToPhone(envelope)

        let optimistic = FastingStateSnapshot(
            isFasting: false,
            startDate: nil,
            targetDuration: nil,
            protocolType: snapshot.protocolType,
            currentStreak: snapshot.currentStreak,
            longestStreak: snapshot.longestStreak,
            lastCompletedFastDate: snapshot.lastCompletedFastDate,
            lastCompletedFastStartDate: snapshot.lastCompletedFastStartDate,
            updatedAt: Date()
        )
        updateLocalSnapshot(optimistic)
    }

    func refreshFromLocalStore() {
        let stored = AppGroupCoordinator.shared.readSnapshot()
        if stored.updatedAt > snapshot.updatedAt {
            self.snapshot = stored
        }
    }

    private func sendCommandToPhone(_ envelope: PendingCommandEnvelope) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            AppGroupCoordinator.shared.enqueueEnvelope(envelope)
            return
        }
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
    ) {
        guard activationState == .activated else { return }
        let pending = AppGroupCoordinator.shared.drainPendingCommands()
        let contextPayload = session.receivedApplicationContext
        Task { @MainActor [weak self] in
            guard let self else { return }
            if !pending.isEmpty {
                for envelope in pending {
                    self.sendCommandToPhone(envelope)
                }
            } else if let incoming = WatchPayload.decodeSnapshot(from: contextPayload),
                      incoming.updatedAt > self.snapshot.updatedAt {
                self.updateLocalSnapshot(incoming)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let incoming = WatchPayload.decodeSnapshot(from: applicationContext) else { return }
        Task { @MainActor in
            if incoming.updatedAt >= self.snapshot.updatedAt {
                self.updateLocalSnapshot(incoming)
            }
        }
    }
}
