//
//  SpeechTextPreprocessorTests.swift
//  VoiceYourTextTests
//
//  読み前処理（数字・英略語・単位）とハイライト範囲の逆引きのテスト。
//  日本語以外の言語で誤発火しないことも固定する。
//

import XCTest
@testable import VoiceYourText

final class SpeechTextPreprocessorTests: XCTestCase {

    private func spoken(_ text: String, language: String? = "ja") -> String {
        SpeechTextPreprocessor.prepare(text, languageCode: language).spoken
    }

    // MARK: - 英略語

    func test_日本語文中の英略語をカタカナ読みにする() {
        XCTAssertEqual(spoken("PDFを開く"), "ピーディーエフを開く")
        XCTAssertEqual(spoken("URLをコピー"), "ユーアールエルをコピー")
        XCTAssertEqual(spoken("iOSアプリ"), "アイオーエスアプリ")
        XCTAssertEqual(spoken("Wi-Fiに接続"), "ワイファイに接続")
    }

    func test_英単語の一部に含まれる略語は置換しない() {
        // "MYPDFFILE" の中の PDF や、"AID" の中の AI を拾わない
        XCTAssertEqual(spoken("MYPDFFILE"), "MYPDFFILE")
        XCTAssertEqual(spoken("AIDを確認"), "AIDを確認")
        XCTAssertEqual(spoken("IDEAを出す"), "IDEAを出す")
    }

    func test_略語が単独で現れる場合は置換する() {
        XCTAssertEqual(spoken("形式はCSV、または JSON"), "形式はシーエスブイ、または ジェイソン")
    }

    // MARK: - 単位

    func test_数字に続く単位をカタカナ読みにする() {
        XCTAssertEqual(spoken("5km走った"), "5キロメートル走った")
        XCTAssertEqual(spoken("体重は60kgです"), "体重は60キログラムです")
        XCTAssertEqual(spoken("容量は500MB"), "容量は500メガバイト")
        XCTAssertEqual(spoken("１２cm"), "１２センチメートル")
    }

    func test_数字が前に無い単位は置換しない() {
        // 「km」単体や英文中の語を壊さない
        XCTAssertEqual(spoken("kmという単位"), "kmという単位")
        XCTAssertEqual(spoken("スペースキー"), "スペースキー")
    }

    // MARK: - 数字・記号

    func test_桁区切りカンマを外す() {
        XCTAssertEqual(spoken("売上は1,234円"), "売上は1234円")
        XCTAssertEqual(spoken("1,234,567"), "1234567")
    }

    func test_3桁区切りでないカンマは残す() {
        // 日付や列挙のカンマを壊さない
        XCTAssertEqual(spoken("1,23"), "1,23")
        XCTAssertEqual(spoken("項目A,項目B"), "項目A,項目B")
    }

    func test_パーセントと摂氏を読みにする() {
        XCTAssertEqual(spoken("達成率は80%です"), "達成率は80パーセントです")
        XCTAssertEqual(spoken("気温は25℃"), "気温は25度")
    }

    // MARK: - 他言語を壊さない

    func test_英語では日本語向けルールを適用しない() {
        XCTAssertEqual(spoken("Open the PDF file", language: "en"), "Open the PDF file")
        XCTAssertEqual(spoken("It is 5km away", language: "en"), "It is 5km away")
        XCTAssertEqual(spoken("Total 1,234 items", language: "en"), "Total 1,234 items")
        XCTAssertEqual(spoken("80% done", language: "en-US"), "80% done")
    }

    func test_その他の言語でも日本語向けルールを適用しない() {
        for language in ["de", "es", "fr", "it", "ko", "zh", "pt", "ru", "th", "vi"] {
            XCTAssertEqual(
                spoken("PDF 1,234 5km 80%", language: language),
                "PDF 1,234 5km 80%",
                "\(language) で日本語向けルールが誤発火している"
            )
        }
    }

    func test_言語がnilなら日本語向けルールを適用しない() {
        XCTAssertEqual(spoken("PDFを開く", language: nil), "PDFを開く")
    }

    // MARK: - ハイライト範囲の逆引き

    func test_変換が無ければ元テキストと同一で範囲もそのまま() {
        let prepared = SpeechTextPreprocessor.prepare("こんにちは", languageCode: "ja")
        XCTAssertTrue(prepared.isIdentity)
        XCTAssertEqual(prepared.spoken, "こんにちは")
        XCTAssertEqual(
            prepared.originalRange(forSpoken: NSRange(location: 0, length: 2)),
            NSRange(location: 0, length: 2)
        )
    }

    func test_置換後の範囲が元テキストの範囲に逆引きできる() {
        let original = "PDFを開く"
        let prepared = SpeechTextPreprocessor.prepare(original, languageCode: "ja")
        XCTAssertEqual(prepared.spoken, "ピーディーエフを開く")

        // 置換部分（"ピーディーエフ" = 7文字）のどこを読んでいても "PDF"(0..<3) 全体を返す
        let inside = prepared.originalRange(forSpoken: NSRange(location: 2, length: 2))
        XCTAssertEqual(inside, NSRange(location: 0, length: 3))

        // 置換されていない "を"（spoken では index 7）は元の index 3 に対応する
        let after = prepared.originalRange(forSpoken: NSRange(location: 7, length: 1))
        XCTAssertEqual(after, NSRange(location: 3, length: 1))
    }

    func test_置換が短くなる場合も後続の範囲が正しくずれる() {
        // "1,234" → "1234"（1文字減る）
        let original = "金額は1,234円です"
        let prepared = SpeechTextPreprocessor.prepare(original, languageCode: "ja")
        XCTAssertEqual(prepared.spoken, "金額は1234円です")

        // spoken の "円" は index 7、original では index 8
        let yen = prepared.originalRange(forSpoken: NSRange(location: 7, length: 1))
        XCTAssertEqual(yen, NSRange(location: 8, length: 1))
    }

    func test_空文字は変換なし() {
        let prepared = SpeechTextPreprocessor.prepare("", languageCode: "ja")
        XCTAssertEqual(prepared.spoken, "")
        XCTAssertTrue(prepared.isIdentity)
        XCTAssertNil(prepared.originalRange(forSpoken: NSRange(location: 0, length: 0)))
    }

    func test_セグメントは元テキストとspokenを隙間なく覆う() {
        let original = "5kmを走り、PDFを読む"
        let prepared = SpeechTextPreprocessor.prepare(original, languageCode: "ja")

        let originalLength = (original as NSString).length
        let spokenLength = (prepared.spoken as NSString).length
        XCTAssertEqual(prepared.segments.map(\.original.length).reduce(0, +), originalLength)
        XCTAssertEqual(prepared.segments.map(\.spoken.length).reduce(0, +), spokenLength)

        // 連続していること
        var expectedOriginal = 0
        var expectedSpoken = 0
        for segment in prepared.segments {
            XCTAssertEqual(segment.original.location, expectedOriginal)
            XCTAssertEqual(segment.spoken.location, expectedSpoken)
            expectedOriginal += segment.original.length
            expectedSpoken += segment.spoken.length
        }
    }

    // MARK: - 改行の整形（韻律）
    //
    // PDF/EPUB は紙面の行幅で機械的に折り返されるため文の途中に改行が入り、
    // AVSpeechSynthesizer がそこで間を置いて一文がぶつ切りになる。
    // 「文が続いている」と確実に言える改行だけを詰め、段落の区切りは残す。

    func test_日本語の文中改行は詰める() {
        XCTAssertEqual(spoken("読み上げ\nナレーター"), "読み上げナレーター")
    }

    func test_句点で終わる行の改行は残す() {
        XCTAssertEqual(spoken("これは一文目です。\n次の文です。"), "これは一文目です。\n次の文です。")
    }

    func test_空行は段落区切りとして残す() {
        XCTAssertEqual(spoken("前の段落\n\n次の段落"), "前の段落\n\n次の段落")
    }

    func test_閉じ括弧で終わる行の改行は残す() {
        XCTAssertEqual(spoken("彼は「そうだ」\nと言った"), "彼は「そうだ」\nと言った")
    }

    func test_次の行が箇条書きなら詰めない() {
        XCTAssertEqual(spoken("次のとおり\n・ひとつめ"), "次のとおり\n・ひとつめ")
        XCTAssertEqual(spoken("次のとおり\n1. ひとつめ"), "次のとおり\n1. ひとつめ")
    }

    func test_読点で終わる行は詰める() {
        XCTAssertEqual(spoken("まず準備をして、\n次に実行する"), "まず準備をして、次に実行する")
    }

    func test_英語の文中改行は半角スペースで繋ぐ() {
        XCTAssertEqual(spoken("hello\nworld", language: "en"), "hello world")
    }

    func test_英語のハイフネーションを解除する() {
        XCTAssertEqual(spoken("narra-\ntor", language: "en"), "narrator")
        XCTAssertEqual(spoken("ナレー-\nション", language: "ja"), "ナレー-\nション")
    }

    func test_英語のピリオドで終わる行は繋がない() {
        XCTAssertEqual(spoken("First line.\nSecond line", language: "en"), "First line.\nSecond line")
    }

    func test_改行を詰めてもハイライト範囲は元テキストを指す() {
        let original = "読み上げ\nナレーター"
        let nsOriginal = original as NSString
        let prepared = SpeechTextPreprocessor.prepare(original, languageCode: "ja")
        XCTAssertEqual(prepared.spoken, "読み上げナレーター")

        // 改行より前も位置はずれない（境界に接するので削除した改行を含んで返る）
        let head = prepared.originalRange(forSpoken: NSRange(location: 0, length: 4))
        XCTAssertNotNil(head)
        XCTAssertEqual(head!.location, 0)
        XCTAssertEqual(
            nsOriginal.substring(with: head!).replacingOccurrences(of: "\n", with: ""),
            "読み上げ"
        )

        // spoken の "ナレーター"(location 4) は、元テキストでは改行をまたいだ location 5。
        // 詰めた改行は「置換された区間」なので、その境界に接する範囲を引くと
        // 改行ごと含めて返る（PreparedSpeechText の仕様。置換元の語全体を返す）。
        // 見たいのは「位置がずれていないこと」なので、改行を除いて比較する。
        let mapped = prepared.originalRange(forSpoken: NSRange(location: 4, length: 5))
        XCTAssertNotNil(mapped)
        XCTAssertEqual(
            nsOriginal.substring(with: mapped!).replacingOccurrences(of: "\n", with: ""),
            "ナレーター"
        )
        XCTAssertEqual(mapped!.location + mapped!.length, nsOriginal.length)
    }

    func test_改行整形は辞書の読み替えと共存する() {
        let prepared = SpeechTextPreprocessor.prepare(
            "設定から\n東京を選ぶ",
            languageCode: "ja",
            readings: [(word: "東京", reading: "とうきょう")]
        )
        XCTAssertEqual(prepared.spoken, "設定からとうきょうを選ぶ")
    }
}
