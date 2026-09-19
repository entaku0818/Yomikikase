//
//  HighQualityVoiceGuide.swift
//  VoiceYourText
//
//  Enhanced / Premium 音声をユーザーに落としてもらうための案内文。
//
//  アプリから高品質音声を直接ダウンロードする公式APIは無い。
//  `UIApplication.openSettingsURLString` で開けるのも「このアプリの設定ページ」までで、
//  音声がある「アクセシビリティ > 読み上げコンテンツ > 声」へ直接飛ぶ手段は無い
//  （App-prefs: のような非公開スキームは審査で弾かれる）。
//  そのため、たどり着けるだけの手順を言葉で示すしかない。ここはその文言を
//  ユニットテストできるよう純粋ロジックとして切り出したもの。
//

import Foundation

enum HighQualityVoiceGuide {

    /// 高品質音声を追加する手順。iOS の設定アプリの階層をそのまま並べる。
    /// 端末の表示言語ではなく「読み上げ言語」に対する案内である点に注意
    /// （日本語を読み上げるなら、声の一覧でも日本語を選ぶ必要がある）。
    static func steps(languageCode: String?) -> [String] {
        [
            "「設定」アプリを開く",
            "アクセシビリティ → 読み上げコンテンツ → 声",
            "\(languageName(languageCode)) を選ぶ",
            downloadStep(languageCode: languageCode),
            "このアプリに戻り、下の一覧から選ぶ"
        ]
    }

    /// 4番目の手順。日本語のときだけ実際の音声名を出す。
    /// 名前が分かっていた方が一覧の中から見つけやすい。
    static func downloadStep(languageCode: String?) -> String {
        if let examples = voiceExamples(languageCode: languageCode) {
            return "\(examples) などの「高品質」をダウンロード"
        }
        return "「高品質」と付いた音声をダウンロード"
    }

    /// その言語で代表的な音声名。分からない言語では nil。
    static func voiceExamples(languageCode: String?) -> String? {
        switch VoiceResolver.primarySubtag(languageCode ?? "") {
        case "ja": return "Kyoko / Otoya / O-ren / Hattori"
        case "en": return "Samantha / Daniel"
        default:   return nil
        }
    }

    /// 設定アプリの「声」の一覧で選ぶ言語の名前。
    static func languageName(_ languageCode: String?) -> String {
        let subtag = VoiceResolver.primarySubtag(languageCode ?? "")
        guard !subtag.isEmpty else { return "読み上げたい言語" }
        return Locale(identifier: "ja_JP").localizedString(forLanguageCode: subtag)
            ?? "読み上げたい言語"
    }

    /// ダウンロードで得られるもの。誘導の理由として出す。
    static let benefit = "iOS標準の音声より自然に読み上げられます。一度入れればオフラインでも使えます。"

    /// 「設定を開く」ボタンの但し書き。
    /// 開けるのはこのアプリの設定ページまでで、そこから自力でたどる必要がある。
    /// ボタンを押した先が期待と違うと迷子になるため、事前に明示する。
    static let openSettingsCaveat = "ボタンでは「設定」アプリが開きます。そこから上の手順でたどってください。"
}
