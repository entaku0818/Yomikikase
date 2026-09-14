//
//  SpeechSynthesizerClientDictionaryTests.swift
//  VoiceYourTextTests
//
//  ユーザー辞書がメイン再生経路（speakWithHighlight）で適用されることのテスト。
//
//  従来 speakWithHighlight は「ハイライトを壊さないため」辞書を適用していなかった。
//  ここでは liveValue の speakWithHighlight が実際に呼ぶ highlightPlan(for:languageCode:readings:)
//  を直接叩き、(1) 読み上げ文字列に辞書が反映される (2) ハイライトは元テキスト基準のまま
//  の 2 点を固定する。
//

import XCTest
import AVFoundation
@testable import VoiceYourText

final class SpeechSynthesizerClientDictionaryTests: XCTestCase {

    private func utterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.3
        utterance.volume = 0.75
        return utterance
    }

    // MARK: - 辞書が適用される

    func test_辞書の読みがspeakWithHighlightの読み上げ文字列に反映される() {
        let plan = SpeechSynthesizerClient.highlightPlan(
            for: utterance("遠藤さんに連絡する"),
            languageCode: "ja",
            readings: [(word: "遠藤", reading: "えんどう")]
        )
        XCTAssertEqual(plan.utterance.speechString, "えんどうさんに連絡する")
    }

    func test_辞書が空なら読み上げ文字列は元のまま() {
        let plan = SpeechSynthesizerClient.highlightPlan(
            for: utterance("こんにちは"),
            languageCode: "ja",
            readings: []
        )
        XCTAssertEqual(plan.utterance.speechString, "こんにちは")
        XCTAssertTrue(plan.prepared.isIdentity)
    }

    func test_辞書は日本語以外でも適用される() {
        // ユーザーの明示指定なので言語で止めない
        let plan = SpeechSynthesizerClient.highlightPlan(
            for: utterance("Call Endo now"),
            languageCode: "en",
            readings: [(word: "Endo", reading: "En-doh")]
        )
        XCTAssertEqual(plan.utterance.speechString, "Call En-doh now")
    }

    func test_複数の辞書エントリが適用され長い語が優先される() {
        let plan = SpeechSynthesizerClient.highlightPlan(
            for: utterance("東京都と東京"),
            languageCode: "ja",
            readings: [
                (word: "東京", reading: "とうきょう"),
                (word: "東京都", reading: "とうきょうと")
            ]
        )
        XCTAssertEqual(plan.utterance.speechString, "とうきょうとととうきょう")
    }

    // MARK: - ハイライトが壊れない

    func test_辞書を適用してもハイライトは元テキスト基準で返る() {
        let original = "遠藤さんに連絡する"
        let plan = SpeechSynthesizerClient.highlightPlan(
            for: utterance(original),
            languageCode: "ja",
            readings: [(word: "遠藤", reading: "えんどう")]
        )

        // 読み上げ側の "えんどう"(0..<4) は、元テキストの "遠藤"(0..<2) に対応する
        let mapped = plan.prepared.originalRange(forSpoken: NSRange(location: 0, length: 4))
        XCTAssertEqual(mapped, NSRange(location: 0, length: 2))

        // 置換の後ろ "さん" は読み上げ側 4..<6、元テキストでは 2..<4
        let after = plan.prepared.originalRange(forSpoken: NSRange(location: 4, length: 2))
        XCTAssertEqual(after, NSRange(location: 2, length: 2))

        // 返された範囲が元テキストの範囲に収まっていること
        let originalLength = (original as NSString).length
        XCTAssertLessThanOrEqual(after!.location + after!.length, originalLength)
    }

    // MARK: - utterance の設定が引き継がれる

    func test_読み上げ文字列を差し替えても速度ピッチ音量を引き継ぐ() {
        let source = utterance("遠藤")
        source.preUtteranceDelay = 0.1
        source.postUtteranceDelay = 0.25

        let plan = SpeechSynthesizerClient.highlightPlan(
            for: source,
            languageCode: "ja",
            readings: [(word: "遠藤", reading: "えんどう")]
        )

        XCTAssertNotEqual(plan.utterance.speechString, source.speechString, "辞書が適用されていない")
        XCTAssertEqual(plan.utterance.rate, source.rate)
        XCTAssertEqual(plan.utterance.pitchMultiplier, source.pitchMultiplier)
        XCTAssertEqual(plan.utterance.volume, source.volume)
        XCTAssertEqual(plan.utterance.preUtteranceDelay, source.preUtteranceDelay)
        XCTAssertEqual(plan.utterance.postUtteranceDelay, source.postUtteranceDelay)
    }

    // MARK: - 辞書と日本語前処理の併用

    func test_辞書は日本語前処理より優先される() {
        // ユーザーが "PDF" に独自の読みを設定していたら、そちらを使う
        let plan = SpeechSynthesizerClient.highlightPlan(
            for: utterance("PDFを開く"),
            languageCode: "ja",
            readings: [(word: "PDF", reading: "ピーデーエフ")]
        )
        XCTAssertEqual(plan.utterance.speechString, "ピーデーエフを開く")
    }
}
