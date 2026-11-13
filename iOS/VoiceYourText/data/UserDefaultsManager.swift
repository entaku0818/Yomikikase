//
//  UserDefaultsManager.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2023/12/17.
//

import Foundation
class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let defaults: UserDefaults

    // Persisted booleans are not proof of a purchase. RevenueCat must verify each launch.
    private var sessionPremiumUser = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // オンボーディング完了フラグ
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "HasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "HasCompletedOnboarding") }
    }

    // インストール日を保存するプロパティ
    var installDate: Date? {
        get {
            defaults.object(forKey: "InstallDate") as? Date
        }
        set {
            defaults.set(newValue, forKey: "InstallDate")
        }
    }

    // レビューのリクエストカウントを保存する
    var reviewRequestCount: Int {
        get {
            defaults.object(forKey: "ReviewRequestCount") as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: "ReviewRequestCount")
        }
    }

    // App Open広告の起動カウント
    // 他機能のカウンタと共有しない専用キー。
    // （別アプリで起動カウンタと録音カウンタが同じキーを共有していて、
    //   広告の表示機会が消えるうえ課金訴求まで誤爆した事故があったため）
    var appOpenAdLaunchCount: Int {
        get {
            defaults.object(forKey: "AppOpenAdLaunchCount") as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: "AppOpenAdLaunchCount")
        }
    }

    // 読み上げ完了カウント
    var speechCompletedCount: Int {
        get {
            defaults.object(forKey: "SpeechCompletedCount") as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: "SpeechCompletedCount")
        }
    }

    // 言語設定
    var languageSetting: String? {
        get {
            defaults.string(forKey: "LanguageSetting")
        }
        set {
            defaults.set(newValue, forKey: "LanguageSetting")
        }
    }

    // 音声設定（デバイスTTS用）
    var selectedVoiceIdentifier: String? {
        get {
            defaults.string(forKey: "SelectedVoiceIdentifier")
        }
        set {
            defaults.set(newValue, forKey: "SelectedVoiceIdentifier")
        }
    }

    /// パーソナルボイスを選んだことがあるか。
    /// true のときだけ起動時に認可を取り直し、再生経路からパーソナルボイスを使えるようにする。
    var usesPersonalVoice: Bool {
        get { defaults.bool(forKey: "UsesPersonalVoice") }
        set { defaults.set(newValue, forKey: "UsesPersonalVoice") }
    }

    // 音声の速度設定
    var speechRate: Float {
        get {
            let rate = defaults.float(forKey: "SpeechRate")
            return rate == 0 ? 0.5 : rate // デフォルト値を設定
        }
        set {
            defaults.set(newValue, forKey: "SpeechRate")
        }
    }

    // 音声の高さ設定
    var speechPitch: Float {
        get {
            let pitch = defaults.float(forKey: "SpeechPitch")
            return pitch == 0 ? 1.0 : pitch // デフォルト値を設定
        }
        set {
            defaults.set(newValue, forKey: "SpeechPitch")
        }
    }
    
    // 起動中に確認されたプレミアム状態。永続化された旧フラグは権限判定に使わない。
    var isPremiumUser: Bool {
        get {
            sessionPremiumUser
        }
        set {
            sessionPremiumUser = newValue
            defaults.removeObject(forKey: "IsPremiumUser")
            
            // 通知を送信して、アプリの他の部分に変更を知らせる
            NotificationCenter.default.post(
                name: Notification.Name("PremiumStatusDidChange"),
                object: nil,
                userInfo: ["isPremium": newValue]
            )
        }
    }
    
    // プレミアムユーザーの購入日を保存するプロパティ
    var premiumPurchaseDate: Date? {
        get {
            defaults.object(forKey: "PremiumPurchaseDate") as? Date
        }
        set {
            defaults.set(newValue, forKey: "PremiumPurchaseDate")
        }
    }
    
    // すべてのプレミアム関連データをリセット
    func resetPremiumStatus() {
        isPremiumUser = false
        premiumPurchaseDate = nil
    }

    // アプリ起動回数
    var appLaunchCount: Int {
        get { defaults.integer(forKey: "AppLaunchCount") }
        set { defaults.set(newValue, forKey: "AppLaunchCount") }
    }

    // レビューダイアログ最終表示日
    var lastReviewRequestDate: Date? {
        get { defaults.object(forKey: "LastReviewRequestDate") as? Date }
        set { defaults.set(newValue, forKey: "LastReviewRequestDate") }
    }

    // 自動の課金案内（オンボーディングのトライアル案内・月1の案内）を最後に出した日時
    var autoPaywallLastShownAt: Date? {
        get { defaults.object(forKey: "AutoPaywallLastShownAt") as? Date }
        set { defaults.set(newValue, forKey: "AutoPaywallLastShownAt") }
    }

    // オンボーディング完了直後のトライアル案内を出したか（1回きり）
    var hasShownOnboardingTrialPaywall: Bool {
        get { defaults.bool(forKey: "HasShownOnboardingTrialPaywall") }
        set { defaults.set(newValue, forKey: "HasShownOnboardingTrialPaywall") }
    }

    // 「はい」ボタン押下済みフラグ
    var hasAnsweredReviewPositively: Bool {
        get { defaults.bool(forKey: "HasAnsweredReviewPositively") }
        set { defaults.set(newValue, forKey: "HasAnsweredReviewPositively") }
    }

    // Kokoro TTS
    var kokoroEnabled: Bool {
        get { defaults.bool(forKey: "KokoroEnabled") }
        set { defaults.set(newValue, forKey: "KokoroEnabled") }
    }

    var kokoroVoice: String? {
        get { defaults.string(forKey: "KokoroVoice") }
        set { defaults.set(newValue, forKey: "KokoroVoice") }
    }
}
