import Foundation
import ComposableArchitecture
import FirebaseAnalytics

struct AnalyticsClient {
    var logEvent: @Sendable (_ name: String, _ parameters: [String: Any]?) -> Void
    var setUserProperty: @Sendable (_ value: String?, _ name: String) -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = Self(
        logEvent: { name, parameters in
            Analytics.logEvent(name, parameters: parameters)
        },
        setUserProperty: { value, name in
            Analytics.setUserProperty(value, forName: name)
        }
    )
    
    static let testValue = Self(
        logEvent: { _, _ in },
        setUserProperty: { _, _ in }
    )
}

extension DependencyValues {
    var analytics: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}

// Analytics Event Names
enum AnalyticsEventName {
    static let viewLanguageSettings = "view_language_settings"
    static let tapSubscription = "tap_subscription"
    static let viewSubscription = "view_subscription"
}

// Analytics Parameter Names
enum AnalyticsParameterName {
    static let source = "source"
    static let screen = "screen"
    static let buttonType = "button_type"
} 