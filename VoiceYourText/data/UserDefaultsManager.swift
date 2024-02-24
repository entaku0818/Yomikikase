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
            // "LanguageSetting"の値を取得、もしなければ"en"をデフォルト値として返す
            return defaults.string(forKey: "LanguageSetting") ?? "en"
        }
        set {
            defaults.set(newValue, forKey: "LanguageSetting")
        }
    }

}
