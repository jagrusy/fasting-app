import SwiftUI
import StoreKit

public enum FeedbackType {
    case featureRequest
    case bugReport

    public var subject: String {
        switch self {
        case .featureRequest:
            return "[Solstice Feature Request]"
        case .bugReport:
            return "[Solstice Bug Report]"
        }
    }

    public var placeholder: String {
        switch self {
        case .featureRequest:
            return "Describe your idea or feature request below:\n\n"
        case .bugReport:
            return "Describe what happened and how to reproduce it below:\n\n"
        }
    }
}

@MainActor
public enum FeedbackHelper {
    public static let supportEmail = "jagrusy+solstice@gmail.com"

    public static func sendFeedback(type: FeedbackType, fastManager: FastManager) {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        let protocolName = fastManager.currentProtocol.name
        let isFasting = fastManager.isFasting ? "Yes" : "No"

        let diagnostics = """


        --- Device Diagnostics (Please do not delete) ---
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(systemVersion)
        Device Model: \(model)
        Selected Protocol: \(protocolName)
        Fasting in Progress: \(isFasting)
        -------------------------------------------------
        """

        let body = "\(type.placeholder)\(diagnostics)"
        let subject = "\(type.subject) v\(appVersion) (\(buildNumber))"

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIPasteboard.general.string = supportEmail
        }
    }

    public static func requestAppStoreReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first(
            where: { $0.activationState == .foregroundActive }
        ) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}
