import Foundation

public struct FastingProtocol: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let fastingHours: Double
    public let eatingHours: Double
    public let description: String

    public var fastingSeconds: TimeInterval {
        fastingHours * 3600
    }

    public var eatingSeconds: TimeInterval {
        eatingHours * 3600
    }

    public var ratioString: String {
        "\(Int(fastingHours)):\(Int(eatingHours))"
    }

    public init(name: String, fastingHours: Double, eatingHours: Double, description: String) {
        self.id = "\(Int(fastingHours)):\(Int(eatingHours))"
        self.name = name
        self.fastingHours = fastingHours
        self.eatingHours = eatingHours
        self.description = description
    }

    public static let presets: [FastingProtocol] = [
        FastingProtocol(name: "Beginner", fastingHours: 12, eatingHours: 12, description: "12 hours fasting, 12 hours eating"),
        FastingProtocol(name: "Light", fastingHours: 14, eatingHours: 10, description: "14 hours fasting, 10 hours eating"),
        FastingProtocol(name: "Popular", fastingHours: 16, eatingHours: 8, description: "16 hours fasting, 8 hours eating"),
        FastingProtocol(name: "Advanced", fastingHours: 18, eatingHours: 6, description: "18 hours fasting, 6 hours eating"),
        FastingProtocol(name: "Warrior", fastingHours: 20, eatingHours: 4, description: "20 hours fasting, 4 hours eating"),
        FastingProtocol(name: "OMAD", fastingHours: 23, eatingHours: 1, description: "23 hours fasting, 1 hour eating")
    ]

    public static let `default` = presets[2] // 16:8

    public static func from(protocolType: String?) -> FastingProtocol {
        guard let type = protocolType else { return .default }
        return presets.first { $0.ratioString == type || $0.id == type } ?? .default
    }
}
