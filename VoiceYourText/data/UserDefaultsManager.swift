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
            return defaults.object(forKey: "InstallDate") as? Date
        }
        set {
            defaults.set(newValue, forKey: "InstallDate")
        }
    }

    // レビューのリクエストカウントを保存する
    var reviewRequestCount: Int {
        get {
            return defaults.object(forKey: "ReviewRequestCount") as? Int ?? 0
        }
        set {
            defaults.set(newValue, forKey: "ReviewRequestCount")
        }
    }

    var languageSetting: String? {
        get {
            return defaults.string(forKey: "LanguageSetting")
        }
        set {
            defaults.set(newValue, forKey: "LanguageSetting")
        }
    }

    // レートを保存するプロパティ
     var speechRate: Float {
         get {
             let rate = defaults.float(forKey: "SpeechRate")
             return rate == 0 ? 0.5 : rate // デフォルト値を設定
         }
         set {
             defaults.set(newValue, forKey: "SpeechRate")
         }
     }

     // ピッチを保存するプロパティ
     var speechPitch: Float {
         get {
             let pitch = defaults.float(forKey: "SpeechPitch")
             return pitch == 0 ? 1.0 : pitch // デフォルト値を設定
         }
         set {
             defaults.set(newValue, forKey: "SpeechPitch")
         }
     }
}
