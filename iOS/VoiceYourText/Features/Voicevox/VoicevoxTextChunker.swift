import Foundation

/// キャラ音声（VOICEVOX）用に文章を文ごとに分ける。
///
/// サーバーは1回300字までしか受け付けず、1文ずつ作って最初の文ができたら再生を始めるため、
/// 文末（。！？ など）と改行で区切る。元の文章の中の位置（UTF-16 の NSRange）を持たせて、
/// 再生中のハイライトに使う。
enum VoicevoxTextChunker {
    struct Chunk: Equatable {
        /// サーバーに送る文字列（前後の空白を除いたもの）
        let text: String
        /// 元の文章の中での位置（UTF-16）。ハイライトに使う
        let range: NSRange
    }

    /// サーバー側の MAX_REQUEST_CHARS と合わせる
    static let defaultMaxChars = 300

    private static let terminators: Set<Character> = ["。", "！", "？", "!", "?", "…", "\n"]
    /// 文末の直後に続く閉じ括弧は前の文に含める（「〜です。」の 」 など）
    private static let trailingClosers: Set<Character> = ["」", "』", "）", ")", "】", "〉", "》", "\"", "”", "’"]
    /// 長すぎる文を途中で切るときの候補
    private static let softBreaks: Set<Character> = ["、", "，", ",", "；", ";", "：", ":", " ", "　"]

    static func chunks(from text: String, maxChars: Int = defaultMaxChars) -> [Chunk] {
        var result: [Chunk] = []
        var sentenceStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            index = text.index(after: index)
            guard terminators.contains(character) else { continue }
            while index < text.endIndex, trailingClosers.contains(text[index]) || (character != "\n" && terminators.contains(text[index]) && text[index] != "\n") {
                index = text.index(after: index)
            }
            appendSentence(text, sentenceStart..<index, maxChars: maxChars, into: &result)
            sentenceStart = index
        }
        if sentenceStart < text.endIndex {
            appendSentence(text, sentenceStart..<text.endIndex, maxChars: maxChars, into: &result)
        }
        return result
    }

    private static func appendSentence(_ text: String, _ range: Range<String.Index>, maxChars: Int, into result: inout [Chunk]) {
        var start = range.lowerBound
        while start < range.upperBound {
            var end = range.upperBound
            if text[start..<end].unicodeScalars.count > maxChars {
                end = splitPoint(text, from: start, before: range.upperBound, maxChars: maxChars)
            }
            appendTrimmed(text, start..<end, into: &result)
            start = end
        }
    }

    /// maxChars 以内で、なるべく読点などの直後で切る位置
    private static func splitPoint(_ text: String, from start: String.Index, before limit: String.Index, maxChars: Int) -> String.Index {
        var scalars = 0
        var hardLimit = start
        var lastSoft: String.Index?
        var index = start
        while index < limit {
            let next = text.index(after: index)
            scalars += text[index].unicodeScalars.count
            if scalars > maxChars { break }
            hardLimit = next
            if softBreaks.contains(text[index]) { lastSoft = next }
            index = next
        }
        return lastSoft ?? hardLimit
    }

    private static func appendTrimmed(_ text: String, _ range: Range<String.Index>, into result: inout [Chunk]) {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, text[lower].isWhitespace { lower = text.index(after: lower) }
        while upper > lower, text[text.index(before: upper)].isWhitespace { upper = text.index(before: upper) }
        guard lower < upper else { return }
        let piece = text[lower..<upper]
        // 記号だけの行（「――」「・・・」など）は読む内容がないので送らない（文字数を使わせない）
        guard piece.contains(where: { $0.isLetter || $0.isNumber }) else { return }
        result.append(Chunk(text: String(piece), range: NSRange(lower..<upper, in: text)))
    }
}
