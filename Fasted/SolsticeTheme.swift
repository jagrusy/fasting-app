import SwiftUI

public enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    public var iconName: String {
        switch self {
        case .system:
            return "circle.righthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
        }
    }
}

public enum SolsticeColors {
    // Solar Gold to Amber palette matching the Solstice app icon
    public static let solarGold = Color(red: 1.0, green: 0.82, blue: 0.35)
    public static let solarAmber = Color(red: 1.0, green: 0.62, blue: 0.12)
    public static let solarFlame = Color(red: 1.0, green: 0.44, blue: 0.08)

    // Goal met palette
    public static let emeraldGlow = Color(red: 0.18, green: 0.82, blue: 0.54)
    public static let tealGlow = Color(red: 0.05, green: 0.65, blue: 0.58)

    public static var solarGradient: LinearGradient {
        LinearGradient(
            colors: [solarGold, solarAmber, solarFlame],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var goalMetGradient: LinearGradient {
        LinearGradient(
            colors: [emeraldGlow, tealGlow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var idleGradient: LinearGradient {
        LinearGradient(
            colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
