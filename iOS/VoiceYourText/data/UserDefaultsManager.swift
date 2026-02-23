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

    private init() {
        defaults = UserDefaults.standard
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

    // Cloud TTS音声設定
    var cloudTTSVoiceId: String? {
        get {
            defaults.string(forKey: "CloudTTSVoiceId")
        }
        set {
            defaults.set(newValue, forKey: "CloudTTSVoiceId")
        }
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
    
    // プレミアムユーザーフラグを保存するプロパティ
    var isPremiumUser: Bool {
        get {
            defaults.bool(forKey: "IsPremiumUser")
        }
        set {
            defaults.set(newValue, forKey: "IsPremiumUser")
            // 変更を即座に同期して他の場所でも反映されるようにする
            defaults.synchronize()
            
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

    // 処理中のTTSジョブ管理（fileId.uuidString → jobId）
    var pendingJobs: [String: String] {
        get { defaults.dictionary(forKey: "PendingTTSJobs") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "PendingTTSJobs") }
    }

    func setPendingJob(fileId: UUID, jobId: String) {
        var jobs = pendingJobs
        jobs[fileId.uuidString] = jobId
        pendingJobs = jobs
    }

    func clearPendingJob(fileId: UUID) {
        var jobs = pendingJobs
        jobs.removeValue(forKey: fileId.uuidString)
        pendingJobs = jobs
    }

    func pendingJobId(for fileId: UUID) -> String? {
        pendingJobs[fileId.uuidString]
    }
}
