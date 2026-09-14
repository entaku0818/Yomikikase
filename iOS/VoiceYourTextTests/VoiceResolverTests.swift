//
//  VoiceResolverTests.swift
//  VoiceYourTextTests
//
//  音声解決ヘルパーのテスト。
//  「設定で選んだ音声が実際の読み上げに使われる」ための中核ロジックなので、
//  identifier 優先とフォールバック条件をここで固定する。
//

import XCTest
@testable import VoiceYourText

final class VoiceResolverTests: XCTestCase {

    /// 端末にある音声を模したテーブル。identifier → 言語コード。
    private let installed: [String: String] = [
        "com.apple.voice.enhanced.ja-JP.Kyoko": "ja-JP",
        "com.apple.voice.premium.en-US.Ava": "en-US",
        "com.apple.voice.compact.en-GB.Daniel": "en-GB"
    ]

    private func lookup(_ identifier: String) -> String? { installed[identifier] }

    // MARK: - identifier 優先

    func test_保存済みidentifierが端末にあり言語も一致すればそれを使う() {
        let selection = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.enhanced.ja-JP.Kyoko",
            languageCode: "ja",
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .identifier("com.apple.voice.enhanced.ja-JP.Kyoko"))
    }

    func test_地域まで含む言語コードでもidentifierを使う() {
        let selection = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.enhanced.ja-JP.Kyoko",
            languageCode: "ja-JP",
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .identifier("com.apple.voice.enhanced.ja-JP.Kyoko"))
    }

    func test_地域違いでも第一サブタグが同じならidentifierを使う() {
        // en 設定で en-GB の音声を選んでいるケース
        let selection = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.compact.en-GB.Daniel",
            languageCode: "en",
            fallbackLanguageCode: "ja-JP",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .identifier("com.apple.voice.compact.en-GB.Daniel"))
    }

    // MARK: - language へのフォールバック

    func test_identifierが未保存ならlanguageにフォールバックする() {
        let selection = VoiceResolver.selection(
            savedIdentifier: nil,
            languageCode: "ja",
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .language("ja"))
    }

    func test_identifierが空文字ならlanguageにフォールバックする() {
        let selection = VoiceResolver.selection(
            savedIdentifier: "",
            languageCode: "ja",
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .language("ja"))
    }

    func test_identifierが端末に存在しなければlanguageにフォールバックする() {
        // 高品質音声を削除した / 別端末から移行した ケース
        let selection = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.premium.ja-JP.Deleted",
            languageCode: "ja",
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .language("ja"))
    }

    func test_identifierの言語が読み上げ言語と違えばlanguageにフォールバックする() {
        // 日本語の声を選んだまま言語設定を英語に変えたケース
        let selection = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.enhanced.ja-JP.Kyoko",
            languageCode: "en",
            fallbackLanguageCode: "ja-JP",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .language("en"))
    }

    func test_言語コードがnilなら端末既定の言語を使う() {
        let selection = VoiceResolver.selection(
            savedIdentifier: nil,
            languageCode: nil,
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .language("en-US"))
    }

    func test_言語コードが空白だけなら端末既定の言語を使う() {
        let selection = VoiceResolver.selection(
            savedIdentifier: nil,
            languageCode: "   ",
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .language("en-US"))
    }

    func test_言語コードがnilでもidentifierが端末既定言語と一致すれば使う() {
        let selection = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.premium.en-US.Ava",
            languageCode: nil,
            fallbackLanguageCode: "en-US",
            voiceLanguage: lookup
        )
        XCTAssertEqual(selection, .identifier("com.apple.voice.premium.en-US.Ava"))
    }

    // MARK: - フォールバックの遅延評価

    /// 回帰防止: fallbackLanguageCode には `AVSpeechSynthesisVoice.currentLanguageCode()` が
    /// 渡される。これは音声サービスへの問い合わせが発生しうるため、言語コードが
    /// 分かっているときに評価してはいけない（評価するとテスト環境で再生処理がハングした）。
    func test_言語コードが分かっているときフォールバックを評価しない() {
        var fallbackEvaluations = 0
        func expensiveFallback() -> String {
            fallbackEvaluations += 1
            return "en-US"
        }

        _ = VoiceResolver.selection(
            savedIdentifier: "com.apple.voice.enhanced.ja-JP.Kyoko",
            languageCode: "ja",
            fallbackLanguageCode: expensiveFallback(),
            voiceLanguage: lookup
        )
        XCTAssertEqual(fallbackEvaluations, 0)

        // identifier が無くても、言語コードがあれば評価しない
        _ = VoiceResolver.selection(
            savedIdentifier: nil,
            languageCode: "ja",
            fallbackLanguageCode: expensiveFallback(),
            voiceLanguage: lookup
        )
        XCTAssertEqual(fallbackEvaluations, 0)
    }

    func test_言語コードが無いときだけフォールバックを評価する() {
        var fallbackEvaluations = 0
        func expensiveFallback() -> String {
            fallbackEvaluations += 1
            return "en-US"
        }

        _ = VoiceResolver.selection(
            savedIdentifier: nil,
            languageCode: nil,
            fallbackLanguageCode: expensiveFallback(),
            voiceLanguage: lookup
        )
        XCTAssertEqual(fallbackEvaluations, 1)
    }

    // MARK: - 言語コードの比較

    func test_第一サブタグの抽出() {
        XCTAssertEqual(VoiceResolver.primarySubtag("ja-JP"), "ja")
        XCTAssertEqual(VoiceResolver.primarySubtag("en_US"), "en")
        XCTAssertEqual(VoiceResolver.primarySubtag("ZH-Hans-CN"), "zh")
        XCTAssertEqual(VoiceResolver.primarySubtag("ja"), "ja")
        XCTAssertEqual(VoiceResolver.primarySubtag(""), "")
    }

    func test_言語の一致判定は地域と大文字小文字を無視する() {
        XCTAssertTrue(VoiceResolver.languagesMatch("ja-JP", "ja"))
        XCTAssertTrue(VoiceResolver.languagesMatch("EN-us", "en-GB"))
        XCTAssertFalse(VoiceResolver.languagesMatch("ja-JP", "en-US"))
        XCTAssertFalse(VoiceResolver.languagesMatch("zh-CN", "ja"))
    }
}
