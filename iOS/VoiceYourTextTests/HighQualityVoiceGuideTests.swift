//
//  HighQualityVoiceGuideTests.swift
//  VoiceYourTextTests
//
//  高品質音声のダウンロード案内文のテスト。
//  アプリから直接ダウンロードするAPIが無く、案内文だけが頼りの導線なので、
//  手順の抜け・言語ごとの出し分けをここで固定する。
//

import XCTest
@testable import VoiceYourText

final class HighQualityVoiceGuideTests: XCTestCase {

    // MARK: - 手順

    func test_手順は設定アプリからアプリに戻るまでを5段で示す() {
        let steps = HighQualityVoiceGuide.steps(languageCode: "ja")
        XCTAssertEqual(steps.count, 5)
        XCTAssertEqual(steps[0], String(localized: "「設定」アプリを開く"))
        XCTAssertEqual(steps[1], String(localized: "アクセシビリティ → 読み上げコンテンツ → 声"))
        XCTAssertEqual(steps[4], String(localized: "このアプリに戻り、下の一覧から選ぶ"))
    }

    func test_手順に読み上げ言語の名前が入る() {
        XCTAssertTrue(HighQualityVoiceGuide.steps(languageCode: "ja")[2].contains(HighQualityVoiceGuide.languageName("ja")))
        XCTAssertTrue(HighQualityVoiceGuide.steps(languageCode: "en")[2].contains(HighQualityVoiceGuide.languageName("en")))
    }

    func test_手順は空にならない() {
        for code in ["ja", "en", "de", "zh", "", nil] as [String?] {
            let steps = HighQualityVoiceGuide.steps(languageCode: code)
            XCTAssertEqual(steps.count, 5, "languageCode=\(code ?? "nil")")
            for step in steps {
                XCTAssertFalse(step.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - 言語名

    func test_言語名はロケール付きでもサブタグで解決する() {
        XCTAssertEqual(HighQualityVoiceGuide.languageName("ja-JP", locale: Locale(identifier: "ja")), "日本語")
        XCTAssertEqual(HighQualityVoiceGuide.languageName("ja", locale: Locale(identifier: "en")), "Japanese")
    }

    func test_言語が不明なら汎用の表現にする() {
        XCTAssertEqual(HighQualityVoiceGuide.languageName(nil), String(localized: "読み上げたい言語"))
        XCTAssertEqual(HighQualityVoiceGuide.languageName(""), String(localized: "読み上げたい言語"))
    }

    // MARK: - 音声名の例

    func test_日本語では実際の音声名を出す() {
        let examples = HighQualityVoiceGuide.voiceExamples(languageCode: "ja")
        XCTAssertNotNil(examples)
        XCTAssertTrue(examples!.contains("Kyoko"), examples!)
        XCTAssertTrue(examples!.contains("Otoya"), examples!)
    }

    func test_音声名が分からない言語では汎用の手順にする() {
        XCTAssertNil(HighQualityVoiceGuide.voiceExamples(languageCode: "de"))
        let step = HighQualityVoiceGuide.downloadStep(languageCode: "de")
        XCTAssertFalse(step.isEmpty)
        XCTAssertFalse(step.contains("Kyoko"), step)
    }

    func test_日本語のダウンロード手順に音声名が含まれる() {
        let step = HighQualityVoiceGuide.downloadStep(languageCode: "ja-JP")
        XCTAssertTrue(step.contains("Kyoko"), step)
        XCTAssertFalse(step.isEmpty)
    }

    // MARK: - 但し書き

    func test_設定ボタンの但し書きが空でない() {
        // openSettingsURLString はアプリ自身の設定ページしか開けない。
        // それを伝えないとボタンを押したユーザーが迷子になるため、必ず文言を持つ。
        XCTAssertFalse(HighQualityVoiceGuide.openSettingsCaveat.isEmpty)
        XCTAssertFalse(HighQualityVoiceGuide.benefit.isEmpty)
    }
}
