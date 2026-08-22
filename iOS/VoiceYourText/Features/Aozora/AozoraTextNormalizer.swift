import Foundation

/// 青空文庫のテキストファイルを読み上げ用のプレーンテキストへ正規化する。
///
/// 青空文庫のテキストには以下の記法が含まれており、そのまま読み上げると
/// 「吾輩わがはいは猫である」「シャープ八字下げ」のようなノイズになる。
/// - ルビ: `吾輩《わがはい》` / `一番｜獰悪《どうあく》`
/// - 入力者注記: `［＃８字下げ］` `※［＃「言＋墟のつくり」、第4水準2-88-74］`
/// - ファイル先頭の記号説明ブロック（`----` で囲まれた部分）
/// - ファイル末尾の底本・入力者情報
///
/// 記法の仕様: https://www.aozora.gr.jp/annotation/
///
/// 副作用のない純粋ロジックとして切り出してあり、ユニットテストの主対象。
enum AozoraTextNormalizer {

    /// 正規化後の作品。
    struct Document: Equatable {
        /// ファイル先頭に書かれている作品名（取れなければ空文字）。
        var title: String
        /// ファイル先頭に書かれている著者名（取れなければ空文字）。
        var author: String
        /// 読み上げ対象の本文。
        var body: String
        /// 底本情報の1行目（`底本：「…」`）。取れなければ空文字。
        var colophon: String
    }

    // MARK: - Decode

    /// 青空文庫のテキストは Shift_JIS(CP932) 配布。JIS X 0213 と UTF-8 もフォールバックで試す。
    static func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .shiftJIS) {
            return text
        }
        let x0213 = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.shiftJIS_X0213.rawValue)
        )
        if let text = String(data: data, encoding: String.Encoding(rawValue: x0213)) {
            return text
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Normalize

    /// 記号説明ヘッダ・底本フッタ・ルビ・注記を取り除いた `Document` を返す。
    static func normalize(_ raw: String) -> Document {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        let (headerLines, afterHeader) = splitHeader(lines)
        let (bodyLines, colophon) = splitColophon(afterHeader)

        let meta = headerLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let body = bodyLines
            .map { stripRubyAndAnnotations($0).trimmingTrailingWhitespace() }
            .joined(separator: "\n")

        return Document(
            title: meta.first.map(stripRubyAndAnnotations) ?? "",
            author: meta.count >= 2 ? stripRubyAndAnnotations(meta[meta.count - 1]) : "",
            // 段落頭の全角スペースを潰さないよう、前後は改行だけを落とす。
            body: collapseBlankLines(body).trimmingCharacters(in: .newlines),
            colophon: stripRubyAndAnnotations(colophon).trimmingCharacters(in: .whitespaces)
        )
    }

    // MARK: - Header / Colophon

    /// 記号説明ブロックの区切り線かどうか（`-` が10個以上だけの行）。
    static func isDividerLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 10 && trimmed.allSatisfy { $0 == "-" }
    }

    /// 先頭の「作品名・著者名」と、記号説明ブロックより後ろの行に分割する。
    /// 区切り線が2本そろっていないファイルは本文のみとして扱う。
    private static func splitHeader(_ lines: [String]) -> (header: [String], rest: [String]) {
        let dividers = lines.indices.filter { isDividerLine(lines[$0]) }
        guard dividers.count >= 2 else {
            return ([], lines)
        }
        let first = dividers[0]
        let second = dividers[1]
        return (Array(lines[..<first]), Array(lines[(second + 1)...]))
    }

    /// 本文と底本情報に分割する。
    private static func splitColophon(_ lines: [String]) -> (body: [String], colophon: String) {
        guard let index = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("底本：") || trimmed.hasPrefix("底本:")
        }) else {
            return (lines, "")
        }
        return (Array(lines[..<index]), lines[index])
    }

    /// 3行以上の連続改行を2行にまとめる。注記だけの行を削ったあとの空白を詰めるために使う。
    static func collapseBlankLines(_ text: String) -> String {
        var result = text
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result
    }

    // MARK: - Ruby / Annotation

    /// ルビと入力者注記を取り除く。
    ///
    /// 正規表現ではなく1文字ずつ走査しているのは、注記が `［＃「※［＃…］」…］` のように
    /// 入れ子になることがあり、非貪欲マッチだと途中で閉じてしまうため。
    static func stripRubyAndAnnotations(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        let chars = Array(text)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            // ※ に続く記法。`※［＃…］` は外字注記、`※《` `※》` は山括弧そのものを表すエスケープ。
            if char == "※", index + 1 < chars.count {
                let next = chars[index + 1]
                if next == "［" {
                    index = skipAnnotation(chars, from: index + 1)
                    continue
                }
                if next == "《" || next == "》" {
                    result.append(next)
                    index += 2
                    continue
                }
            }

            // 入力者注記 ［＃…］。［ で始まっても ＃ が続かなければ本文の一部として残す。
            if char == "［", index + 1 < chars.count, chars[index + 1] == "＃" {
                index = skipAnnotation(chars, from: index)
                continue
            }

            // ルビ本体。
            if char == "《" {
                index = skipRuby(chars, from: index)
                continue
            }

            // ルビの範囲開始記号。読み上げには不要なので落とすだけ。
            if char == "｜" {
                index += 1
                continue
            }

            result.append(char)
            index += 1
        }

        return result
    }

    /// `［` から対応する `］` の次の位置までスキップする（入れ子対応）。
    private static func skipAnnotation(_ chars: [Character], from start: Int) -> Int {
        var depth = 0
        var index = start
        while index < chars.count {
            if chars[index] == "［" {
                depth += 1
            } else if chars[index] == "］" {
                depth -= 1
                if depth == 0 {
                    return index + 1
                }
            }
            index += 1
        }
        // 閉じ括弧が無い壊れた入力。行末まで捨てる。
        return chars.count
    }

    /// `《` から対応する `》` の次の位置までスキップする。
    private static func skipRuby(_ chars: [Character], from start: Int) -> Int {
        var index = start + 1
        while index < chars.count {
            if chars[index] == "》" {
                return index + 1
            }
            index += 1
        }
        return chars.count
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var result = self
        while let last = result.last, last == " " || last == "\t" {
            result.removeLast()
        }
        return result
    }
}
