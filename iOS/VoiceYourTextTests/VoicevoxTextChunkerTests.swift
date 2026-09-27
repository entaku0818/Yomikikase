import XCTest
@testable import VoiceYourText

final class VoicevoxTextChunkerTests: XCTestCase {
    private func texts(_ text: String, maxChars: Int = 300) -> [String] {
        VoicevoxTextChunker.chunks(from: text, maxChars: maxChars).map(\.text)
    }

    func testSplitsAtSentenceEndsAndNewlines() {
        XCTAssertEqual(
            texts("今日は晴れです。明日は雨？\n第一章\nそれでは始めます！"),
            ["今日は晴れです。", "明日は雨？", "第一章", "それでは始めます！"]
        )
    }

    func testClosingBracketStaysWithSentence() {
        XCTAssertEqual(
            texts("彼は「行こう。」と言った。『本当に？』"),
            ["彼は「行こう。」", "と言った。", "『本当に？』"]
        )
    }

    func testRepeatedTerminatorsStayTogether() {
        XCTAssertEqual(texts("えっ！？本当に……？うん"), ["えっ！？", "本当に……？", "うん"])
    }

    func testSkipsBlankAndSymbolOnlyLines() {
        XCTAssertEqual(texts("はじめに。\n\n　\n――\n・・・\n本文です。"), ["はじめに。", "本文です。"])
    }

    func testRangesPointAtOriginalText() {
        let text = "  前書き。\n本文です。"
        let chunks = VoicevoxTextChunker.chunks(from: text)
        let ns = text as NSString
        XCTAssertEqual(chunks.map { ns.substring(with: $0.range) }, ["前書き。", "本文です。"])
    }

    func testRangesAreUTF16ForEmoji() {
        let text = "😀です。次。"
        let chunks = VoicevoxTextChunker.chunks(from: text)
        XCTAssertEqual(chunks.map(\.range), [NSRange(location: 0, length: 5), NSRange(location: 5, length: 2)])
    }

    func testLongSentenceIsSplitAtCommaWithinLimit() {
        let text = "あいうえお、かきくけこ、さしすせそたちつてと。"
        let result = texts(text, maxChars: 10)
        // 10字を超えるので読点の直後で切り、読点が無い部分は10字で切る。残った「。」だけの断片は読まないので送らない
        XCTAssertEqual(result, ["あいうえお、", "かきくけこ、", "さしすせそたちつてと"])
        XCTAssertTrue(result.allSatisfy { $0.unicodeScalars.count <= 10 })
    }

    func testLongSentenceWithoutCommaIsHardCut() {
        let text = String(repeating: "あ", count: 25)
        let result = texts(text, maxChars: 10)
        XCTAssertEqual(result.map(\.count), [10, 10, 5])
    }

    func testEveryChunkFitsServerLimit() {
        let text = String(repeating: "長い文章が続きます、", count: 80) + "終わり。"
        let chunks = VoicevoxTextChunker.chunks(from: text)
        XCTAssertTrue(chunks.allSatisfy { $0.text.unicodeScalars.count <= VoicevoxTextChunker.defaultMaxChars })
        XCTAssertEqual(chunks.map(\.text).joined(), text)
    }
}
