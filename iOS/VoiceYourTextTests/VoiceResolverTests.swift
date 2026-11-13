//
//  VoiceResolverTests.swift
//  VoiceYourTextTests
//
//  音声解決ヘルパーのテスト。
//  「設定で選んだ音声が実際の読み上げに使われる」ための中核ロジックなので、
//  identifier 優先とフォールバック条件をここで固定する。
//

import AVFoundation
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

    // MARK: - ダウンロード済み音声の自動選択

    private func candidate(_ id: String, language: String = "ja-JP",
                           quality: AVSpeechSynthesisVoiceQuality = .default,
                           explicit: Bool = false) -> VoiceResolver.Candidate {
        .init(identifier: id, language: language, quality: quality, requiresExplicitSelection: explicit)
    }

    func test_未選択なら同じ地域の最も高品質な音声を使う() {
        let voices = [candidate("enhanced", quality: .enhanced), candidate("premium", quality: .premium)]
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("compact"), availableVoices: voices
        ), "premium")
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("compact"), availableVoices: [voices[0]]
        ), "enhanced")
    }

    func test_高品質音声がなくても既定の声で再生できる() {
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("compact"), availableVoices: []
        ), "compact")
    }

    func test_自動選択では品質のために地域や文字体系を変えない() {
        for (target, other) in [("en-GB", "en-US"), ("zh-CN", "zh-TW"), ("ja-JP", "en-US")] {
            XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
                defaultVoice: candidate("default", language: target),
                availableVoices: [candidate("other", language: other, quality: .premium)]
            ), "default")
        }
    }

    func test_自動選択でも言語タグの表記揺れを許容する() {
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("default", language: "en_US"),
            availableVoices: [candidate("enhanced", language: "EN-us", quality: .enhanced)]
        ), "enhanced")
    }

    func test_同品質の声へは勝手に切り替えず品質も下げない() {
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("system", quality: .premium),
            availableVoices: [candidate("a", quality: .premium), candidate("b", quality: .enhanced)]
        ), "system")
    }

    func test_複数の高品質音声は一覧の順序に依存しない() {
        let voices = [candidate("b", quality: .premium), candidate("a", quality: .premium)]
        for ordered in [voices, Array(voices.reversed())] {
            XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
                defaultVoice: candidate("default"), availableVoices: ordered
            ), "a")
        }
    }

    func test_個人の声や特殊な声は自動選択しない() {
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("default"),
            availableVoices: [candidate("personal", quality: .premium, explicit: true)]
        ), "default")
        XCTAssertEqual(VoiceResolver.automaticVoiceIdentifier(
            defaultVoice: candidate("personal", explicit: true),
            availableVoices: [candidate("premium", quality: .premium)]
        ), "personal")
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
