import Foundation
import ComposableArchitecture
import FirebaseAnalytics
import CryptoKit
import RevenueCat

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

/// A pseudonymous join key for contract outcomes and product usage; never use email or content.
/// Hash format is versioned so offline RevenueCat analysis can reproduce the same key.
enum SubscriptionAnalyticsIdentity {
    static func userID(for revenueCatID: String) -> String {
        let digest = SHA256.hash(data: Data(("voiceyourtext:rc:v1:" + revenueCatID).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func synchronize() {
        guard !AppDelegate.isRunningTests, Purchases.isConfigured else {
            return
        }
        Analytics.setUserID(userID(for: Purchases.shared.appUserID))
        if let instanceID = Analytics.appInstanceID() {
            Purchases.shared.attribution.setFirebaseAppInstanceID(instanceID)
        }
        Analytics.setUserProperty("1", forName: "trial_measurement_version")
        #if DEBUG
        Analytics.setUserProperty("debug", forName: "build_environment")
        #else
        Analytics.setUserProperty("release", forName: "build_environment")
        #endif
    }
}
