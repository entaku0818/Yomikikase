//
//  SpeechTextPreprocessor.swift
//  VoiceYourText
//
//  読み上げ前にテキストを整える。
//
//  1. ユーザー辞書の読み方を適用する（全言語）
//  2. 日本語のときだけ、英略語・単位・桁区切りカンマを読みやすい表記に置き換える
//
//  置換するとハイライト用の NSRange がずれるため、変換後テキスト（spoken）から
//  元テキスト（original）へ範囲を逆引きできるよう対応表（segments）を一緒に返す。
//  これにより、従来「ハイライトを壊さないため」という理由でユーザー辞書が
//  適用されていなかったメイン再生経路（speakWithHighlight）でも辞書を使える。
//

import Foundation

// MARK: - 変換結果

/// 読み上げ用テキストと、元テキストへの範囲逆引き情報。
struct PreparedSpeechText: Equatable {

    /// 変換前後の対応する 1 区間。
    struct Segment: Equatable {
        /// 変換後テキスト上の範囲
        let spoken: NSRange
        /// 元テキスト上の範囲
        let original: NSRange
        /// 置換が起きた区間か（false なら 1:1 対応）
        let isReplaced: Bool
    }

    let original: String
    let spoken: String
    /// spoken の位置昇順。spoken/original 双方を隙間なく覆う。
    let segments: [Segment]

    /// 変換が一切起きていない（spoken == original）か。
    var isIdentity: Bool { segments.allSatisfy { !$0.isReplaced } }

    /// 変換後テキスト上の範囲を、元テキスト上の範囲へ変換する。
    ///
    /// 置換された区間に少しでも重なる場合は、その置換元の語全体を含む範囲を返す
    /// （「PDF」→「ピーディーエフ」の途中を読んでいるときは「PDF」全体をハイライトする）。
    /// 対応する区間が無ければ nil。
    func originalRange(forSpoken range: NSRange) -> NSRange? {
        guard !segments.isEmpty else { return nil }

        var lower = Int.max
        var upper = Int.min

        for segment in segments {
            guard intersects(segment.spoken, range) else { continue }

            if segment.isReplaced {
                // 置換区間は分割できないので語全体を採用する
                lower = min(lower, segment.original.location)
                upper = max(upper, segment.original.location + segment.original.length)
            } else {
                // 1:1 区間は重なった分だけを切り出す
                let offset = range.location - segment.spoken.location
                let start = segment.original.location + max(0, offset)
                let overlapEnd = min(
                    range.location + range.length,
                    segment.spoken.location + segment.spoken.length
                )
                let end = segment.original.location + (overlapEnd - segment.spoken.location)
                lower = min(lower, start)
                upper = max(upper, max(start, end))
            }
        }

        guard lower != Int.max, upper >= lower else { return nil }
        return NSRange(location: lower, length: upper - lower)
    }

    /// ゼロ長の範囲も「その位置に触れている」とみなして交差判定する。
    private func intersects(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        let lhsEnd = lhs.location + lhs.length
        let rhsEnd = rhs.location + rhs.length
        if lhs.length == 0 || rhs.length == 0 {
            return lhs.location <= rhsEnd && rhs.location <= lhsEnd
        }
        return lhs.location < rhsEnd && rhs.location < lhsEnd
    }

    /// 変換なしの結果を作る。
    static func identity(_ text: String) -> PreparedSpeechText {
        let full = NSRange(location: 0, length: (text as NSString).length)
        return PreparedSpeechText(
            original: text,
            spoken: text,
            segments: full.length == 0
                ? []
                : [Segment(spoken: full, original: full, isReplaced: false)]
        )
    }
}

// MARK: - 前処理本体

enum SpeechTextPreprocessor {

    /// 置換ルール 1 件。
    struct Rule {
        /// 元テキストに対する正規表現
        let pattern: String
        /// 置換後の文字列
        let replacement: String
    }

    /// 読み上げ用テキストを組み立てる。
    ///
    /// - Parameters:
    ///   - text: 元テキスト
    ///   - languageCode: 読み上げ言語（"ja" / "ja-JP" / "en" など）。
    ///     日本語以外では日本語向けルールを一切適用しない。
    ///   - readings: ユーザー辞書の (単語, 読み)。全言語で適用する。
    static func prepare(
        _ text: String,
        languageCode: String?,
        readings: [(word: String, reading: String)] = []
    ) -> PreparedSpeechText {
        guard !text.isEmpty else { return .identity(text) }

        let nsText = text as NSString
        var candidates: [(range: NSRange, replacement: String, priority: Int)] = []

        // 優先度 0: ユーザー辞書。ユーザーの明示指定なので最優先。
        // 長い単語から先に見て、短い単語が長い単語の一部を食わないようにする。
        for entry in readings.sorted(by: { $0.word.count > $1.word.count }) {
            guard !entry.word.isEmpty, entry.word != entry.reading else { continue }
            for range in ranges(of: entry.word, in: nsText) {
                candidates.append((range, entry.reading, 0))
            }
        }

        let isJapanese = VoiceResolver.primarySubtag(
            VoiceResolver.normalizedTarget(languageCode: languageCode, fallback: "")
        ) == "ja"

        // 優先度 1: 日本語のときだけ働くルール
        if isJapanese {
            for rule in japaneseRules {
                for range in regexRanges(pattern: rule.pattern, in: nsText) {
                    candidates.append((range, rule.replacement, 1))
                }
            }
        }

        // 優先度 2: 改行の整形（全言語）。語の読み替えとは重ならないので最後に見る。
        for rule in newlineRules(japanese: isJapanese) {
            for range in regexRanges(pattern: rule.pattern, in: nsText) {
                candidates.append((range, rule.replacement, 2))
            }
        }

        guard !candidates.isEmpty else { return .identity(text) }

        // 重なりを解消する: 位置が早い順 → 優先度が高い順 → 長い順 に採用し、
        // すでに採用した範囲と重なるものは捨てる。
        candidates.sort { lhs, rhs in
            if lhs.range.location != rhs.range.location {
                return lhs.range.location < rhs.range.location
            }
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.range.length > rhs.range.length
        }

        var accepted: [(range: NSRange, replacement: String)] = []
        var consumedUpTo = 0
        for candidate in candidates {
            guard candidate.range.location >= consumedUpTo else { continue }
            accepted.append((candidate.range, candidate.replacement))
            consumedUpTo = candidate.range.location + candidate.range.length
        }

        guard !accepted.isEmpty else { return .identity(text) }

        // 対応表を作りながら変換後テキストを組み立てる
        var spoken = ""
        var segments: [PreparedSpeechText.Segment] = []
        var cursor = 0

        for item in accepted {
            if item.range.location > cursor {
                let plainRange = NSRange(location: cursor, length: item.range.location - cursor)
                let plain = nsText.substring(with: plainRange)
                segments.append(
                    .init(
                        spoken: NSRange(location: (spoken as NSString).length, length: (plain as NSString).length),
                        original: plainRange,
                        isReplaced: false
                    )
                )
                spoken += plain
            }

            segments.append(
                .init(
                    spoken: NSRange(
                        location: (spoken as NSString).length,
                        length: (item.replacement as NSString).length
                    ),
                    original: item.range,
                    isReplaced: true
                )
            )
            spoken += item.replacement
            cursor = item.range.location + item.range.length
        }

        if cursor < nsText.length {
            let tailRange = NSRange(location: cursor, length: nsText.length - cursor)
            let tail = nsText.substring(with: tailRange)
            segments.append(
                .init(
                    spoken: NSRange(location: (spoken as NSString).length, length: (tail as NSString).length),
                    original: tailRange,
                    isReplaced: false
                )
            )
            spoken += tail
        }

        return PreparedSpeechText(original: text, spoken: spoken, segments: segments)
    }

    // MARK: - 日本語向けルール

    /// 日本語の文中で誤読されやすい表記のルール。
    ///
    /// 英略語は前後がアルファベットでないときだけ置換する（`MYPDFFILE` の中は触らない）。
    /// 単位は直前が数字のときだけ置換する（`km` 単体の文字列は触らない）。
    /// 日本語以外の言語では `prepare` 側で丸ごとスキップされる。
    static let japaneseRules: [Rule] = {
        var rules: [Rule] = []

        // 桁区切りカンマを外す（"1,234" → "1234"）。
        // 3 桁区切りの形だけを対象にして、日付や列挙のカンマは触らない。
        rules.append(Rule(pattern: "(?<=[0-9]),(?=[0-9]{3}(?![0-9]))", replacement: ""))

        // 英略語
        let abbreviations: [(String, String)] = [
            ("iOS", "アイオーエス"),
            ("Wi-Fi", "ワイファイ"),
            ("WiFi", "ワイファイ"),
            ("EPUB", "イーパブ"),
            ("HTML", "エイチティーエムエル"),
            ("JSON", "ジェイソン"),
            ("PDF", "ピーディーエフ"),
            ("URL", "ユーアールエル"),
            ("API", "エーピーアイ"),
            ("CPU", "シーピーユー"),
            ("GPU", "ジーピーユー"),
            ("USB", "ユーエスビー"),
            ("FAQ", "エフエーキュー"),
            ("SNS", "エスエヌエス"),
            ("OCR", "オーシーアール"),
            ("CSV", "シーエスブイ"),
            ("DVD", "ディーブイディー"),
            ("TTS", "ティーティーエス"),
            ("AI", "エーアイ"),
            ("ID", "アイディー"),
            ("OS", "オーエス"),
            ("PC", "ピーシー"),
            ("TV", "ティービー"),
            ("UI", "ユーアイ"),
            ("UX", "ユーエックス"),
            ("CD", "シーディー")
        ]
        for (token, reading) in abbreviations {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            rules.append(
                Rule(pattern: "(?<![A-Za-z])\(escaped)(?![A-Za-z])", replacement: reading)
            )
        }

        // 単位（直前が半角/全角数字のときのみ）
        let units: [(String, String)] = [
            ("km", "キロメートル"),
            ("cm", "センチメートル"),
            ("mm", "ミリメートル"),
            ("kg", "キログラム"),
            ("mg", "ミリグラム"),
            ("ml", "ミリリットル"),
            ("mL", "ミリリットル"),
            ("MHz", "メガヘルツ"),
            ("kHz", "キロヘルツ"),
            ("MB", "メガバイト"),
            ("GB", "ギガバイト"),
            ("KB", "キロバイト"),
            ("TB", "テラバイト")
        ]
        for (token, reading) in units {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            rules.append(
                Rule(pattern: "(?<=[0-9０-９])\(escaped)(?![A-Za-z])", replacement: reading)
            )
        }

        // 記号
        rules.append(Rule(pattern: "(?<=[0-9０-９])[%％]", replacement: "パーセント"))
        rules.append(Rule(pattern: "(?<=[0-9０-９])(?:℃|°C)", replacement: "度"))

        return rules
    }()

    /// 改行まわりの整形ルール。
    ///
    /// PDF や EPUB から取り出したテキストは紙面の行幅で機械的に折り返されているため、
    /// 文の途中に改行が入る。`AVSpeechSynthesizer` は改行で間を置くので、そのまま読むと
    /// 一文が毎行ぶつ切りになり、抑揚も行ごとに切れて不自然になる。
    /// 「文が続いている」と確実に言える改行だけを詰める。
    ///
    /// 誤爆を避けるため、前後の文字種を厳しく見て以下は**触らない**:
    ///   - 空行（＝段落の区切り）。前後どちらかが改行なら一致しない
    ///   - 句点・感嘆符・閉じ括弧で終わる行（＝文が終わっている）
    ///   - 次の行が箇条書きや番号で始まる場合（後続の文字種の条件から外れる）
    static func newlineRules(japanese: Bool) -> [Rule] {
        var rules: [Rule] = []

        // 英語のハイフネーション解除。行末の "-" で割られた語を繋ぐ。
        // 例: "narra-\ntor" → "narrator"
        rules.append(Rule(pattern: "(?<=[A-Za-z])-\\n(?=[a-z])", replacement: ""))

        if japanese {
            // 前後とも日本語の本文文字のときだけ詰める。区切り文字を入れない。
            // 例: "読み上げ\nナレーター" → "読み上げナレーター"
            // ASCII が絡む改行は単語がくっつく恐れがあるので対象外。
            let jaBody = "ぁ-んァ-ヴー一-龥々〆ヵヶ、「『（【〔［"
            let jaTail = "ぁ-んァ-ヴー一-龥々〆ヵヶ、"
            rules.append(Rule(pattern: "(?<=[\(jaTail)])\\n(?=[\(jaBody)])", replacement: ""))
        } else {
            // 英語は半角スペースで繋ぐ。小文字またはカンマで終わり、小文字で始まる行のみ。
            rules.append(Rule(pattern: "(?<=[a-z,])\\n(?=[a-z])", replacement: " "))
        }

        return rules
    }

    // MARK: - 検索ユーティリティ


    /// 単純な文字列一致の全出現位置。
    private static func ranges(of needle: String, in haystack: NSString) -> [NSRange] {
        var result: [NSRange] = []
        var searchStart = 0
        while searchStart < haystack.length {
            let searchRange = NSRange(location: searchStart, length: haystack.length - searchStart)
            let found = haystack.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound, found.length > 0 else { break }
            result.append(found)
            searchStart = found.location + found.length
        }
        return result
    }

    /// 正規表現の全出現位置。パターンが不正なら空配列（読み上げ自体は壊さない）。
    private static func regexRanges(pattern: String, in haystack: NSString) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex
            .matches(in: haystack as String, range: NSRange(location: 0, length: haystack.length))
            .map(\.range)
            .filter { $0.length > 0 }
    }
}
