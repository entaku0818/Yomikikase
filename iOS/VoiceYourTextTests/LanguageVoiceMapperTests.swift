//
//  LanguageVoiceMapperTests.swift
//  VoiceYourTextTests
//
//  言語コード → Cloud TTS ボイスID / ロケール変換のユニットテスト。
//

import XCTest
@testable import VoiceYourText

final class LanguageVoiceMapperTests: XCTestCase {

    // MARK: - voiceId(for:)

    func test_voiceId_日本語() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "ja"), "ja-jp-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "ja-JP"), "ja-jp-female-a")
    }

    func test_voiceId_英語() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "en"), "en-us-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "en-US"), "en-us-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "en-GB"), "en-us-female-a")
    }

    func test_voiceId_中国語() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "zh"), "zh-cn-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "zh-CN"), "zh-cn-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "zh-Hans"), "zh-cn-female-a")
    }

    func test_voiceId_ポルトガル語() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "pt"), "pt-br-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "pt-BR"), "pt-br-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "pt-PT"), "pt-br-female-a")
    }

    func test_voiceId_ロシア語() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "ru"), "ru-ru-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "ru-RU"), "ru-ru-female-a")
    }

    func test_voiceId_未知の言語は日本語へフォールバックすること() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "xx"), "ja-jp-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: ""), "ja-jp-female-a")
    }

    func test_voiceId_大文字小文字を無視すること() {
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "JA-JP"), "ja-jp-female-a")
        XCTAssertEqual(LanguageVoiceMapper.voiceId(for: "ZH-CN"), "zh-cn-female-a")
    }

    // MARK: - locale(for:)

    func test_locale_日本語() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "ja"), "ja-JP")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "ja-JP"), "ja-JP")
    }

    func test_locale_英語はUSとGBを区別すること() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "en"), "en-US")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "en-US"), "en-US")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "en-GB"), "en-GB")
    }

    /// 中国語ロケールは Google Cloud TTS 仕様で cmn-CN（zh-CN ではない）であること。
    func test_locale_中国語はcmnCNを返すこと() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "zh"), "cmn-CN")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "zh-CN"), "cmn-CN")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "zh-Hans"), "cmn-CN")
        // 誤った zh-CN を返していないことを明示的に確認
        XCTAssertNotEqual(LanguageVoiceMapper.locale(for: "zh"), "zh-CN")
    }

    func test_locale_ポルトガル語はptBRを返すこと() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "pt"), "pt-BR")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "pt-BR"), "pt-BR")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "pt-PT"), "pt-BR")
    }

    func test_locale_ロシア語はruRUを返すこと() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "ru"), "ru-RU")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "ru-RU"), "ru-RU")
    }

    func test_locale_未知の言語は日本語へフォールバックすること() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "xx"), "ja-JP")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: ""), "ja-JP")
    }

    func test_locale_大文字小文字を無視すること() {
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "ZH-CN"), "cmn-CN")
        XCTAssertEqual(LanguageVoiceMapper.locale(for: "PT-BR"), "pt-BR")
    }
}
