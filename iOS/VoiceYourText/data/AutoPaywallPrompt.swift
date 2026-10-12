//
//  AutoPaywallPrompt.swift
//  VoiceYourText
//
//  自動で出す課金案内（オンボーディング直後のトライアル案内・月1の案内）の発火と記録。issue #159
//  表示判定そのものは PaywallAnalytics パッケージの AutoPaywallPolicy（swift test で検証）。
//

import Foundation
import PaywallAnalytics

enum AutoPaywallPrompt {
    /// 起動から月1の案内を出すまでの待ち時間（画面が落ち着いてから出す）
    static let launchDelayNanoseconds: UInt64 = 2_000_000_000

    /// オンボーディング完了直後: 条件を満たせば記録して true を返す（呼び出し側でペイウォールを出す）
    static func promptAfterOnboarding(
        defaults: UserDefaultsManager = .shared,
        now: Date = Date(),
        analytics: AnalyticsClient
    ) -> Bool {
        guard AutoPaywallPolicy.shouldShowOnboardingTrial(
            isPremium: defaults.isPremiumUser,
            hasShownOnboardingTrial: defaults.hasShownOnboardingTrialPaywall
        ) else {
            return false
        }
        defaults.hasShownOnboardingTrialPaywall = true
        record(.onboardingTrial, defaults: defaults, now: now, analytics: analytics)
        return true
    }

    /// 起動時の月1の案内を出すべきか（待ち時間なしの判定）
    static func shouldPromptMonthly(
        defaults: UserDefaultsManager = .shared,
        now: Date = Date(),
        isSpeaking: Bool,
        didShowAppOpenAd: Bool
    ) -> Bool {
        AutoPaywallPolicy.shouldShowMonthly(
            now: now,
            isPremium: defaults.isPremiumUser,
            installDate: defaults.installDate,
            lastShownAt: defaults.autoPaywallLastShownAt,
            isSpeaking: isSpeaking,
            didShowAppOpenAd: didShowAppOpenAd
        )
    }

    /// 起動時判定: 条件を満たせば少し待ち、その時点でも読み上げていなければ記録して true を返す。
    @MainActor
    static func promptMonthlyOnLaunch(
        didShowAppOpenAd: Bool,
        isSpeaking: () -> Bool,
        analytics: AnalyticsClient
    ) async -> Bool {
        guard shouldPromptMonthly(isSpeaking: isSpeaking(), didShowAppOpenAd: didShowAppOpenAd) else {
            return false
        }
        try? await Task.sleep(nanoseconds: launchDelayNanoseconds)
        // 待っている間に読み上げを始めていたら出さない
        guard shouldPromptMonthly(isSpeaking: isSpeaking(), didShowAppOpenAd: didShowAppOpenAd) else {
            return false
        }
        record(.monthlyPrompt, defaults: .shared, now: Date(), analytics: analytics)
        return true
    }

    private static func record(
        _ trigger: AutoPaywallPolicy.Trigger,
        defaults: UserDefaultsManager,
        now: Date,
        analytics: AnalyticsClient
    ) {
        defaults.autoPaywallLastShownAt = now
        let event = AutoPaywallPolicy.shownEvent(trigger)
        analytics.logEvent(event.name, event.parameters)
    }
}
