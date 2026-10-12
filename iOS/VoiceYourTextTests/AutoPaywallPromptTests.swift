//
//  AutoPaywallPromptTests.swift
//  VoiceYourTextTests
//
//  自動の課金案内（issue #159）の記録と、UserDefaults の値を使った判定
//

import XCTest
import Dependencies
@testable import VoiceYourText

@MainActor
final class AutoPaywallPromptTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var savedIsPremium = false
    private var savedInstallDate: Date?

    override func setUp() {
        super.setUp()
        savedIsPremium = UserDefaultsManager.shared.isPremiumUser
        savedInstallDate = UserDefaultsManager.shared.installDate
        resetDefaults()
    }

    override func tearDown() {
        resetDefaults()
        UserDefaultsManager.shared.isPremiumUser = savedIsPremium
        UserDefaultsManager.shared.installDate = savedInstallDate
        super.tearDown()
    }

    private func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: "AutoPaywallLastShownAt")
        UserDefaults.standard.removeObject(forKey: "HasShownOnboardingTrialPaywall")
        UserDefaultsManager.shared.isPremiumUser = false
    }

    private func analytics(_ events: LockIsolated<[String]>) -> AnalyticsClient {
        AnalyticsClient(
            logEvent: { name, params in
                events.withValue { $0.append("\(name):\(params?["trigger"] as? String ?? "")") }
            },
            setUserProperty: { _, _ in }
        )
    }

    // MARK: - オンボーディング直後

    func test_オンボーディング直後のトライアル案内は1回だけ出して記録すること() {
        let events = LockIsolated<[String]>([])

        XCTAssertTrue(AutoPaywallPrompt.promptAfterOnboarding(now: now, analytics: analytics(events)))
        XCTAssertFalse(AutoPaywallPrompt.promptAfterOnboarding(now: now, analytics: analytics(events)))

        XCTAssertEqual(events.value, ["auto_paywall_shown:onboarding_trial"])
        XCTAssertEqual(UserDefaultsManager.shared.autoPaywallLastShownAt, now)
        XCTAssertTrue(UserDefaultsManager.shared.hasShownOnboardingTrialPaywall)
    }

    func test_課金済みならオンボーディング直後に出さないこと() {
        UserDefaultsManager.shared.isPremiumUser = true
        let events = LockIsolated<[String]>([])

        XCTAssertFalse(AutoPaywallPrompt.promptAfterOnboarding(now: now, analytics: analytics(events)))
        XCTAssertEqual(events.value, [])
        XCTAssertNil(UserDefaultsManager.shared.autoPaywallLastShownAt)
    }

    // MARK: - 月1（保存値を使った判定）

    func test_オンボーディングの案内から30日は月1の案内を出さないこと() {
        UserDefaultsManager.shared.installDate = now
        _ = AutoPaywallPrompt.promptAfterOnboarding(now: now, analytics: .testValue)

        XCTAssertFalse(AutoPaywallPrompt.shouldPromptMonthly(now: now.addingTimeInterval(29 * day), isSpeaking: false, didShowAppOpenAd: false))
        XCTAssertTrue(AutoPaywallPrompt.shouldPromptMonthly(now: now.addingTimeInterval(30 * day), isSpeaking: false, didShowAppOpenAd: false))
    }

    func test_インストール3日以内と除外条件では月1の案内を出さないこと() {
        UserDefaultsManager.shared.installDate = now

        XCTAssertFalse(AutoPaywallPrompt.shouldPromptMonthly(now: now.addingTimeInterval(2 * day), isSpeaking: false, didShowAppOpenAd: false))
        let later = now.addingTimeInterval(10 * day)
        XCTAssertTrue(AutoPaywallPrompt.shouldPromptMonthly(now: later, isSpeaking: false, didShowAppOpenAd: false))
        XCTAssertFalse(AutoPaywallPrompt.shouldPromptMonthly(now: later, isSpeaking: true, didShowAppOpenAd: false))
        XCTAssertFalse(AutoPaywallPrompt.shouldPromptMonthly(now: later, isSpeaking: false, didShowAppOpenAd: true))
        UserDefaultsManager.shared.isPremiumUser = true
        XCTAssertFalse(AutoPaywallPrompt.shouldPromptMonthly(now: later, isSpeaking: false, didShowAppOpenAd: false))
    }

    func test_月1の案内は読み上げ中なら出さず記録もしないこと() async {
        UserDefaultsManager.shared.installDate = Date().addingTimeInterval(-10 * day)
        let events = LockIsolated<[String]>([])

        let shown = await AutoPaywallPrompt.promptMonthlyOnLaunch(
            didShowAppOpenAd: false,
            isSpeaking: { true },
            analytics: analytics(events)
        )

        XCTAssertFalse(shown)
        XCTAssertEqual(events.value, [])
        XCTAssertNil(UserDefaultsManager.shared.autoPaywallLastShownAt)
    }
}
