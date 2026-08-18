import SwiftUI

public enum MetabolicStage: Int, CaseIterable, Identifiable {
    case bloodSugarReset = 0
    case glycogenDepletion = 1
    case fatBurning = 2
    case autophagy = 3
    case deepKetosis = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .bloodSugarReset:
            return "Blood Sugar Reset"
        case .glycogenDepletion:
            return "Glycogen Depletion"
        case .fatBurning:
            return "Fat Burning & Ketosis"
        case .autophagy:
            return "Autophagy & Cell Renewal"
        case .deepKetosis:
            return "Deep Ketosis & Growth"
        }
    }

    public var shortTitle: String {
        switch self {
        case .bloodSugarReset:
            return "Sugar Reset"
        case .glycogenDepletion:
            return "Glycogen Rest"
        case .fatBurning:
            return "Fat Burning"
        case .autophagy:
            return "Autophagy"
        case .deepKetosis:
            return "Deep Ketosis"
        }
    }

    public var timeRangeString: String {
        switch self {
        case .bloodSugarReset:
            return "0 – 4 Hours"
        case .glycogenDepletion:
            return "4 – 12 Hours"
        case .fatBurning:
            return "12 – 18 Hours"
        case .autophagy:
            return "18 – 24 Hours"
        case .deepKetosis:
            return "24+ Hours"
        }
    }

    public var systemIcon: String {
        switch self {
        case .bloodSugarReset:
            return "drop.fill"
        case .glycogenDepletion:
            return "bolt.fill"
        case .fatBurning:
            return "flame.fill"
        case .autophagy:
            return "sparkles"
        case .deepKetosis:
            return "star.fill"
        }
    }

    public var color: Color {
        switch self {
        case .bloodSugarReset:
            return .blue
        case .glycogenDepletion:
            return .orange
        case .fatBurning:
            return .red
        case .autophagy:
            return .purple
        case .deepKetosis:
            return .green
        }
    }

    public var summary: String {
        switch self {
        case .bloodSugarReset:
            return "Insulin levels drop, blood glucose normalizes, and digestion settles."
        case .glycogenDepletion:
            return "Stored liver glycogen is consumed, shifting your metabolism toward stored fats."
        case .fatBurning:
            return "Fat oxidation accelerates and blood ketone levels rise as your primary energy source."
        case .autophagy:
            return "Cellular recycling activates, clearing out damaged mitochondria and misfolded proteins."
        case .deepKetosis:
            return "Maximal ketone production, reduced systemic inflammation, and elevated growth hormone."
        }
    }

    public var startSeconds: TimeInterval {
        switch self {
        case .bloodSugarReset:
            return 0
        case .glycogenDepletion:
            return 4 * 3600
        case .fatBurning:
            return 12 * 3600
        case .autophagy:
            return 18 * 3600
        case .deepKetosis:
            return 24 * 3600
        }
    }

    public static func stage(for elapsedSeconds: TimeInterval) -> MetabolicStage {
        let hours = elapsedSeconds / 3600.0
        if hours < 4.0 {
            return .bloodSugarReset
        } else if hours < 12.0 {
            return .glycogenDepletion
        } else if hours < 18.0 {
            return .fatBurning
        } else if hours < 24.0 {
            return .autophagy
        } else {
            return .deepKetosis
        }
    }
}
