import Foundation
import ComposableArchitecture

/// TCAから利用する設定保存の窓口。liveValueは標準UserDefaults、テストは専用suiteを注入できる。
@DependencyClient
struct UserDefaultsClient: Sendable {
    // 言語・音声
    /// 読み上げ言語コード。未設定ならnil。
    var languageSetting: @Sendable () -> String? = { nil }
    /// 対応する設定値を保存する。
    var setLanguageSetting: @Sendable (String?) -> Void
    /// AVSpeechSynthesisVoiceの識別子。未選択ならnil。
    var selectedVoiceIdentifier: @Sendable () -> String? = { nil }
    /// 対応する設定値を保存する。
    var setSelectedVoiceIdentifier: @Sendable (String?) -> Void

    // 音声パラメータ
    /// 読み上げ速度。未設定または保存値0なら0.5。
    var speechRate: @Sendable () -> Float = { 0.5 }
    /// 対応する設定値を保存する。
    var setSpeechRate: @Sendable (Float) -> Void
    /// 声の高さ。未設定または保存値0なら1.0。
    var speechPitch: @Sendable () -> Float = { 1.0 }
    /// 対応する設定値を保存する。
    var setSpeechPitch: @Sendable (Float) -> Void

    // プレミアム
    /// 保存済みのプレミアム状態。購読の最新状態の検証は購入処理側で行う。
    var isPremiumUser: @Sendable () -> Bool = { false }
    /// 状態を保存し、PremiumStatusDidChange通知で画面へ変更を伝える。
    var setIsPremiumUser: @Sendable (Bool) -> Void
    /// 保存済みの購入日時。未記録ならnil。
    var premiumPurchaseDate: @Sendable () -> Date? = { nil }
    /// 対応する設定値を保存する。
    var setPremiumPurchaseDate: @Sendable (Date?) -> Void

    // Kokoro TTS
    /// 端末上のKokoro音声を使用する設定。モデルの有無は別途確認する。
    var kokoroEnabled: @Sendable () -> Bool = { false }
    /// 対応する設定値を保存する。
    var setKokoroEnabled: @Sendable (Bool) -> Void
    /// 選択したKokoroVoiceのrawValue。未設定ならnil。
    var kokoroVoice: @Sendable () -> String? = { nil }
    /// 対応する設定値を保存する。
    var setKokoroVoice: @Sendable (String?) -> Void

    // オンボーディング
    /// 初期案内が完了済みか。
    var hasCompletedOnboarding: @Sendable () -> Bool = { false }
    /// 対応する設定値を保存する。
    var setHasCompletedOnboarding: @Sendable (Bool) -> Void

    // その他
    /// 読み上げ完了の保存済み回数。
    var speechCompletedCount: @Sendable () -> Int = { 0 }
    /// 対応する設定値を保存する。
    var setSpeechCompletedCount: @Sendable (Int) -> Void
    /// アプリ起動の保存済み回数。
    var appLaunchCount: @Sendable () -> Int = { 0 }
    /// 対応する設定値を保存する。
    var setAppLaunchCount: @Sendable (Int) -> Void
    /// アプリが記録した初回起動日時。未記録ならnil。
    var installDate: @Sendable () -> Date? = { nil }
    /// 対応する設定値を保存する。
    var setInstallDate: @Sendable (Date?) -> Void
    /// レビュー依頼の保存済み回数。
    var reviewRequestCount: @Sendable () -> Int = { 0 }
    /// 対応する設定値を保存する。
    var setReviewRequestCount: @Sendable (Int) -> Void
    /// 前回レビュー依頼日時。未記録ならnil。
    var lastReviewRequestDate: @Sendable () -> Date? = { nil }
    /// 対応する設定値を保存する。
    var setLastReviewRequestDate: @Sendable (Date?) -> Void
    /// レビュー質問に肯定回答した記録。
    var hasAnsweredReviewPositively: @Sendable () -> Bool = { false }
    /// 対応する設定値を保存する。
    var setHasAnsweredReviewPositively: @Sendable (Bool) -> Void
}

extension UserDefaultsClient: DependencyKey {
    static var liveValue: Self { live(store: .standard) }

    /// 保存先を差し替えられる live 実装。
    /// 本番は `liveValue`（= UserDefaults.standard）。テストは専用スイートを渡して
    /// `UserDefaults.standard` の状態（テストホストのアプリが書き込むもの・
    /// 検索ドメインに残る値）から切り離す。挙動は store 以外まったく同じ。
    static func live(store d: UserDefaults) -> Self {
        return Self(
            languageSetting: { d.string(forKey: "LanguageSetting") },
            setLanguageSetting: { d.set($0, forKey: "LanguageSetting") },
            selectedVoiceIdentifier: { d.string(forKey: "SelectedVoiceIdentifier") },
            setSelectedVoiceIdentifier: { d.set($0, forKey: "SelectedVoiceIdentifier") },

            speechRate: { let v = d.float(forKey: "SpeechRate"); return v == 0 ? 0.5 : v },
            setSpeechRate: { d.set($0, forKey: "SpeechRate") },
            speechPitch: { let v = d.float(forKey: "SpeechPitch"); return v == 0 ? 1.0 : v },
            setSpeechPitch: { d.set($0, forKey: "SpeechPitch") },
            isPremiumUser: { d.bool(forKey: "IsPremiumUser") },
            setIsPremiumUser: { newValue in
                d.set(newValue, forKey: "IsPremiumUser")
                d.synchronize()
                NotificationCenter.default.post(
                    name: Notification.Name("PremiumStatusDidChange"),
                    object: nil,
                    userInfo: ["isPremium": newValue]
                )
            },
            premiumPurchaseDate: { d.object(forKey: "PremiumPurchaseDate") as? Date },
            setPremiumPurchaseDate: { d.set($0, forKey: "PremiumPurchaseDate") },
            kokoroEnabled: { d.bool(forKey: "KokoroEnabled") },
            setKokoroEnabled: { d.set($0, forKey: "KokoroEnabled") },
            kokoroVoice: { d.string(forKey: "KokoroVoice") },
            setKokoroVoice: { d.set($0, forKey: "KokoroVoice") },
            hasCompletedOnboarding: { d.bool(forKey: "HasCompletedOnboarding") },
            setHasCompletedOnboarding: { d.set($0, forKey: "HasCompletedOnboarding") },
            speechCompletedCount: { d.object(forKey: "SpeechCompletedCount") as? Int ?? 0 },
            setSpeechCompletedCount: { d.set($0, forKey: "SpeechCompletedCount") },
            appLaunchCount: { d.integer(forKey: "AppLaunchCount") },
            setAppLaunchCount: { d.set($0, forKey: "AppLaunchCount") },
            installDate: { d.object(forKey: "InstallDate") as? Date },
            setInstallDate: { d.set($0, forKey: "InstallDate") },
            reviewRequestCount: { d.object(forKey: "ReviewRequestCount") as? Int ?? 0 },
            setReviewRequestCount: { d.set($0, forKey: "ReviewRequestCount") },
            lastReviewRequestDate: { d.object(forKey: "LastReviewRequestDate") as? Date },
            setLastReviewRequestDate: { d.set($0, forKey: "LastReviewRequestDate") },
            hasAnsweredReviewPositively: { d.bool(forKey: "HasAnsweredReviewPositively") },
            setHasAnsweredReviewPositively: { d.set($0, forKey: "HasAnsweredReviewPositively") }
        )
    }
}

extension UserDefaultsClient: TestDependencyKey {
    static let testValue = Self(
        languageSetting: { nil },
        setLanguageSetting: { _ in },
        selectedVoiceIdentifier: { nil },
        setSelectedVoiceIdentifier: { _ in },

        speechRate: { 0.5 },
        setSpeechRate: { _ in },
        speechPitch: { 1.0 },
        setSpeechPitch: { _ in },
        isPremiumUser: { false },
        setIsPremiumUser: { _ in },
        premiumPurchaseDate: { nil },
        setPremiumPurchaseDate: { _ in },
        kokoroEnabled: { false },
        setKokoroEnabled: { _ in },
        kokoroVoice: { nil },
        setKokoroVoice: { _ in },
        hasCompletedOnboarding: { false },
        setHasCompletedOnboarding: { _ in },
        speechCompletedCount: { 0 },
        setSpeechCompletedCount: { _ in },
        appLaunchCount: { 0 },
        setAppLaunchCount: { _ in },
        installDate: { nil },
        setInstallDate: { _ in },
        reviewRequestCount: { 0 },
        setReviewRequestCount: { _ in },
        lastReviewRequestDate: { nil },
        setLastReviewRequestDate: { _ in },
        hasAnsweredReviewPositively: { false },
        setHasAnsweredReviewPositively: { _ in }
    )
}

extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
