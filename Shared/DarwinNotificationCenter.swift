import Foundation

public final class DarwinNotificationCenter: @unchecked Sendable {
    public static let shared = DarwinNotificationCenter()
    public static let stateChangedNotification = "com.grusy.SolsticeFast.stateChanged"

    private init() {}

    public func post(name: String = stateChangedNotification) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(name as CFString)
        CFNotificationCenterPostNotification(center, cfName, nil, nil, true)
    }

    public func observe(
        name: String = stateChangedNotification,
        handler: @escaping @Sendable () -> Void
    ) -> ObserverToken {
        let token = ObserverToken(name: name, handler: handler)

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(name as CFString)
        let observer = Unmanaged.passUnretained(token).toOpaque()

        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let token = Unmanaged<ObserverToken>.fromOpaque(observer).takeUnretainedValue()
                token.handler()
            },
            cfName.rawValue,
            nil,
            .deliverImmediately
        )
        return token
    }

    public func removeObserver(_ token: ObserverToken) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(token.name as CFString)
        let observer = Unmanaged.passUnretained(token).toOpaque()
        CFNotificationCenterRemoveObserver(center, observer, cfName, nil)
    }

    public final class ObserverToken: @unchecked Sendable {
        fileprivate let name: String
        fileprivate let handler: @Sendable () -> Void

        fileprivate init(name: String, handler: @escaping @Sendable () -> Void) {
            self.name = name
            self.handler = handler
        }

        deinit {
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            let cfName = CFNotificationName(name as CFString)
            let observer = Unmanaged.passUnretained(self).toOpaque()
            CFNotificationCenterRemoveObserver(center, observer, cfName, nil)
        }
    }
}
