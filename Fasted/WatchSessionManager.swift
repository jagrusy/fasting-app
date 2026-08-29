import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public final class WatchSessionManager: NSObject, @unchecked Sendable {
    public static let shared = WatchSessionManager()

    private override init() {
        super.init()
    }
}
