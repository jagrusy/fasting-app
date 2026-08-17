import Foundation

public enum CenterDisplayMode: String, CaseIterable {
    case elapsed = "ELAPSED"
    case remaining = "REMAINING"
    case percentage = "COMPLETED"

    public var next: CenterDisplayMode {
        switch self {
        case .elapsed: return .remaining
        case .remaining: return .percentage
        case .percentage: return .elapsed
        }
    }
}
