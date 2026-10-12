import Foundation

/// 自動で出す課金案内（ペイウォール）の表示判定。issue #159
///
/// シンプル録音（VoiceMemo #228）と同じルール:
/// - オンボーディング完了直後に1回だけトライアル案内
/// - その後は非課金ユーザーに30日に1回、起動時に案内
/// - 課金済み・読み上げ中・使い始めて数日・App Open 広告を出した起動では出さない
///
/// 判定だけを持つ純粋なロジック。UserDefaults や画面の状態は呼び出し側が渡す。
public enum AutoPaywallPolicy {
    /// 自動の課金案内（オンボーディングのトライアル案内も含む）の最短間隔
    public static let interval: TimeInterval = 30 * 24 * 60 * 60
    /// インストールしてから月1の案内を出さない期間
    public static let gracePeriod: TimeInterval = 3 * 24 * 60 * 60

    /// 自動の課金案内の種類。`auto_paywall_shown` の trigger と paywall_view の source に使う
    public enum Trigger: String, Sendable, CaseIterable {
        case onboardingTrial = "onboarding_trial"
        case monthlyPrompt = "monthly_prompt"

        public var source: PaywallSource {
            switch self {
            case .onboardingTrial:
                return .onboardingTrial
            case .monthlyPrompt:
                return .monthlyPrompt
            }
        }
    }

    /// オンボーディング完了直後のトライアル案内を出すか（1回きり）
    public static func shouldShowOnboardingTrial(isPremium: Bool, hasShownOnboardingTrial: Bool) -> Bool {
        !isPremium && !hasShownOnboardingTrial
    }

    /// 起動時に月1の課金案内を出すか
    /// - Parameters:
    ///   - installDate: インストール日（初回起動日）。未記録なら出さない
    ///   - lastShownAt: 前回、自動で課金案内を出した日時（オンボーディングのトライアル案内も含む）
    ///   - isSpeaking: 読み上げ中か
    ///   - didShowAppOpenAd: この起動で App Open 広告を出したか
    public static func shouldShowMonthly(
        now: Date,
        isPremium: Bool,
        installDate: Date?,
        lastShownAt: Date?,
        isSpeaking: Bool,
        didShowAppOpenAd: Bool
    ) -> Bool {
        guard !isPremium, !isSpeaking, !didShowAppOpenAd else { return false }
        guard let installDate, now.timeIntervalSince(installDate) >= gracePeriod else { return false }
        if let lastShownAt, now.timeIntervalSince(lastShownAt) < interval {
            return false
        }
        return true
    }

    /// `auto_paywall_shown` イベントの (名前, パラメータ)
    public static func shownEvent(_ trigger: Trigger) -> (name: String, parameters: [String: String]) {
        ("auto_paywall_shown", ["trigger": trigger.rawValue])
    }
}
