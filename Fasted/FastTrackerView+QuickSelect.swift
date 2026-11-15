import Foundation

enum QuickSelectMode: String, Identifiable {
    case startFast
    case choosePlan
    case retargetGoal

    var id: String { rawValue }

    @MainActor
    func presentation(
        fastManager: FastManager,
        onStartFast: @escaping (FastingProtocol) -> Void
    ) -> ProtocolPickerPresentation {
        switch self {
        case .startFast:
            return .quickSelect(
                title: "Start a Fast",
                customButtonTitle: { "Start \($0)-Hour Fast" },
                selectedProtocolId: fastManager.currentProtocol.ratioString,
                accessibilityIdPrefix: "start_menu_",
                onPick: onStartFast
            )
        case .choosePlan:
            return .quickSelect(
                title: "Fasting Plan",
                customButtonTitle: { "Select \($0)-Hour Plan" },
                selectedProtocolId: fastManager.currentProtocol.ratioString,
                accessibilityIdPrefix: "plan_menu_",
                onPick: { proto in
                    fastManager.updateSelectedProtocol(proto.ratioString)
                }
            )
        case .retargetGoal:
            return .quickSelect(
                title: "Change Fast Goal",
                customButtonTitle: { "Set \($0)-Hour Goal" },
                selectedProtocolId: fastManager.protocolForActiveFast()?.ratioString,
                accessibilityIdPrefix: "retarget_menu_",
                onPick: { proto in
                    guard let fast = fastManager.activeFast else { return }
                    fastManager.updateActiveFast(
                        startDate: fast.startDate ?? Date(),
                        targetDuration: proto.fastingSeconds,
                        protocolType: proto.ratioString
                    )
                }
            )
        }
    }
}
