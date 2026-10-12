import XCTest
@testable import PaywallAnalytics

/// 自動の課金案内（issue #159）の表示判定
final class AutoPaywallPolicyTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func shouldShowMonthly(
        isPremium: Bool = false,
        installedDaysAgo: Double? = 10,
        lastShownDaysAgo: Double? = nil,
        isSpeaking: Bool = false,
        didShowAppOpenAd: Bool = false
    ) -> Bool {
        AutoPaywallPolicy.shouldShowMonthly(
            now: now,
            isPremium: isPremium,
            installDate: installedDaysAgo.map { now.addingTimeInterval(-$0 * day) },
            lastShownAt: lastShownDaysAgo.map { now.addingTimeInterval(-$0 * day) },
            isSpeaking: isSpeaking,
            didShowAppOpenAd: didShowAppOpenAd
        )
    }

    // MARK: - オンボーディング直後のトライアル案内

    func test_onboardingTrial_showsOnceForFreeUser() {
        XCTAssertTrue(AutoPaywallPolicy.shouldShowOnboardingTrial(isPremium: false, hasShownOnboardingTrial: false))
        XCTAssertFalse(AutoPaywallPolicy.shouldShowOnboardingTrial(isPremium: false, hasShownOnboardingTrial: true))
    }

    func test_onboardingTrial_notForPremium() {
        XCTAssertFalse(AutoPaywallPolicy.shouldShowOnboardingTrial(isPremium: true, hasShownOnboardingTrial: false))
    }

    // MARK: - 月1の案内: 日数

    func test_monthly_showsWhenNeverShownAndPastGracePeriod() {
        XCTAssertTrue(shouldShowMonthly(installedDaysAgo: 3, lastShownDaysAgo: nil))
    }

    func test_monthly_notWithinGracePeriodAfterInstall() {
        XCTAssertFalse(shouldShowMonthly(installedDaysAgo: 0))
        XCTAssertFalse(shouldShowMonthly(installedDaysAgo: 2.99))
    }

    func test_monthly_notWhenInstallDateUnknown() {
        XCTAssertFalse(shouldShowMonthly(installedDaysAgo: nil))
    }

    func test_monthly_notWithin30DaysOfLastShown() {
        XCTAssertFalse(shouldShowMonthly(installedDaysAgo: 100, lastShownDaysAgo: 0))
        XCTAssertFalse(shouldShowMonthly(installedDaysAgo: 100, lastShownDaysAgo: 29.99))
    }

    func test_monthly_showsAfter30DaysOfLastShown() {
        XCTAssertTrue(shouldShowMonthly(installedDaysAgo: 100, lastShownDaysAgo: 30))
        XCTAssertTrue(shouldShowMonthly(installedDaysAgo: 100, lastShownDaysAgo: 365))
    }

    func test_monthly_onboardingTrialCountsAsLastShown() {
        // オンボーディングのトライアル案内（インストール当日）から30日は月1案内を出さない
        XCTAssertFalse(shouldShowMonthly(installedDaysAgo: 20, lastShownDaysAgo: 20))
        XCTAssertTrue(shouldShowMonthly(installedDaysAgo: 31, lastShownDaysAgo: 31))
    }

    // MARK: - 月1の案内: 課金状態・除外条件

    func test_monthly_notForPremium() {
        XCTAssertFalse(shouldShowMonthly(isPremium: true))
        XCTAssertFalse(shouldShowMonthly(isPremium: true, installedDaysAgo: 100, lastShownDaysAgo: 365))
    }

    func test_monthly_notWhileSpeaking() {
        XCTAssertFalse(shouldShowMonthly(isSpeaking: true))
    }

    func test_monthly_notOnAppOpenAdLaunch() {
        XCTAssertFalse(shouldShowMonthly(didShowAppOpenAd: true))
    }

    // MARK: - 計測

    func test_trigger_mapsToPaywallSource() {
        XCTAssertEqual(AutoPaywallPolicy.Trigger.onboardingTrial.source, .onboardingTrial)
        XCTAssertEqual(AutoPaywallPolicy.Trigger.monthlyPrompt.source, .monthlyPrompt)
        XCTAssertEqual(PaywallAnalyticsEvent.paywallView(source: .monthlyPrompt).parameters, ["source": "monthly_prompt"])
    }

    func test_shownEvent() {
        let event = AutoPaywallPolicy.shownEvent(.onboardingTrial)
        XCTAssertEqual(event.name, "auto_paywall_shown")
        XCTAssertEqual(event.parameters, ["trigger": "onboarding_trial"])
    }
}
