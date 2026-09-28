import Foundation

public struct FastingProtocol: Identifiable, Hashable {
    /// The value persisted in `Fast.protocolType` / `UserSettings.selectedProtocol` and sent to the
    /// Watch: a ratio such as "16:8" for daily protocols, or "36h" for a fixed-length fast.
    public let id: String
    public let name: String
    public let fastingHours: Double
    /// Zero for fixed-length fasts of a day or more, which have no eating window.
    public let eatingHours: Double
    public let description: String

    public var fastingSeconds: TimeInterval {
        fastingHours * 3600
    }

    public var eatingSeconds: TimeInterval {
        eatingHours * 3600
    }

    /// The persisted identifier (see `id`). Named for the daily protocols it was introduced with.
    public var ratioString: String {
        id
    }

    public var hasEatingWindow: Bool {
        eatingHours > 0
    }

    public init(name: String, fastingHours: Double, eatingHours: Double, description: String) {
        self.init(
            id: "\(Int(fastingHours)):\(Int(eatingHours))",
            name: name,
            fastingHours: fastingHours,
            eatingHours: eatingHours,
            description: description
        )
    }

    private init(id: String, name: String, fastingHours: Double, eatingHours: Double, description: String) {
        self.id = id
        self.name = name
        self.fastingHours = fastingHours
        self.eatingHours = eatingHours
        self.description = description
    }

    public static let presets: [FastingProtocol] = [
        FastingProtocol(
            name: "Beginner",
            fastingHours: 12,
            eatingHours: 12,
            description: "12 hours fasting, 12 hours eating"
        ),
        FastingProtocol(
            name: "Light",
            fastingHours: 14,
            eatingHours: 10,
            description: "14 hours fasting, 10 hours eating"
        ),
        FastingProtocol(
            name: "Popular",
            fastingHours: 16,
            eatingHours: 8,
            description: "16 hours fasting, 8 hours eating"
        ),
        FastingProtocol(
            name: "Advanced",
            fastingHours: 18,
            eatingHours: 6,
            description: "18 hours fasting, 6 hours eating"
        ),
        FastingProtocol(
            name: "Warrior",
            fastingHours: 20,
            eatingHours: 4,
            description: "20 hours fasting, 4 hours eating"
        ),
        FastingProtocol(
            name: "OMAD",
            fastingHours: 23,
            eatingHours: 1,
            description: "23 hours fasting, 1 hour eating"
        )
    ]

    public static let `default` = presets[2] // 16:8

    private static let extendedPresetHours = [24, 36, 48, 72]

    /// Longer fasts, identified by length alone ("36h").
    ///
    /// Watch builds before these existed read any such identifier as 16:8. The Watch starts fasts
    /// from the idle snapshot's `protocolType`, which is the Settings selection, so keep that
    /// selection limited to the daily `presets` until the Watch contract carries the goal length.
    public static let extendedPresets: [FastingProtocol] = extendedPresetHours.map { fixedLength(hours: $0) }

    public static var allPresets: [FastingProtocol] {
        presets + extendedPresets
    }

    /// Lengths offered for a custom fast.
    public static let customHoursRange: ClosedRange<Int> = 12...72

    /// Upper bound on a parsed fixed-length identifier, so a corrupt value can't produce an absurd goal.
    static let maxFixedLengthHours = 7 * 24

    /// A fast defined only by its length. Lengths shorter than a day keep the rest of the day as an
    /// eating window, so they behave like the daily protocols; a day or longer has none.
    public static func fixedLength(hours: Int) -> FastingProtocol {
        let isPreset = extendedPresetHours.contains(hours)
        return FastingProtocol(
            id: "\(hours)h",
            name: isPreset ? "\(hours)-Hour Fast" : "Custom",
            fastingHours: Double(hours),
            eatingHours: Double(max(0, 24 - hours)),
            description: "\(hours) hours fasting"
        )
    }

    /// Falls back to 16:8 only for a missing or unparseable identifier.
    public static func from(protocolType: String?) -> FastingProtocol {
        guard let type = protocolType else { return .default }
        return known(protocolType: type) ?? .default
    }

    /// The protocol an identifier names: a preset ratio, or any well-formed fixed length such as
    /// "30h". Nil when it is neither.
    public static func known(protocolType type: String) -> FastingProtocol? {
        if let preset = allPresets.first(where: { $0.id == type }) {
            return preset
        }
        guard type.hasSuffix("h"),
              let hours = Int(type.dropLast()),
              (1...maxFixedLengthHours).contains(hours) else {
            return nil
        }
        return fixedLength(hours: hours)
    }

    /// Label to display for a fast, given both of the values it stores.
    ///
    /// `from(protocolType:)` silently falls back to 16:8 for any unrecognized string, so a fast whose
    /// `targetDuration` no longer matches its `protocolType` would otherwise render a ratio that
    /// contradicts its own goal. Returns the ratio only when the two genuinely agree.
    public static func label(forTargetDuration duration: TimeInterval, protocolType: String?) -> String {
        guard let type = protocolType,
              let proto = known(protocolType: type),
              abs(proto.fastingSeconds - duration) < 1 else {
            return "Custom"
        }
        return proto.ratioString
    }
}
