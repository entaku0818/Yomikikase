import Foundation
import MLXUtilsLibrary

/// Japanese G2P processor.
///
/// パイプライン:
///   1. 日本語テキスト → ひらがな（CFStringTokenizer・漢字の読みとカタカナ正規化を担う）
///   2. 読みの正規化（NFKC → カタカナ→ひらがな → 数字・ラテン文字の読み下し）
///   3. ひらがな → Kokoro の IPA 音素
///
/// 重要: 3 で出す文字は必ず Kokoro の語彙（`Resources/config.json` の `vocab`）に
/// 存在するものだけにすること。語彙外の文字は `Tokenizer.tokenize` が無言で捨てるため、
/// その音がまるごと消えたまま気付けない。
/// 例: IPA の有声軟口蓋破裂音は `ɡ`(U+0261) で、ASCII の `g`(U+0067) は語彙に無い。
final class JapaneseG2PProcessor: G2PProcessor {

    func setLanguage(_ language: Language) throws {
        guard language == .ja else { throw G2PProcessorError.unsupportedLanguage }
    }

    func process(input: String) throws -> (String, [MToken]?) {
        let prepared = Self.prepareForTokenization(input)
        let hiragana = toHiragana(prepared)
        let normalized = Self.normalizeReading(hiragana)
        let ipa = Self.hiraganaToIPA(normalized)
        return (ipa, nil)
    }

    // MARK: - Japanese text → hiragana via CFStringTokenizer
    // Handles kanji readings and katakana normalization automatically.

    private func toHiragana(_ text: String) -> String {
        let cfText = text as CFString
        let range = CFRangeMake(0, CFStringGetLength(cfText))
        let locale = Locale(identifier: "ja_JP") as CFLocale
        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault, cfText, range,
            kCFStringTokenizerUnitWordBoundary, locale
        )!
        let nsText = text as NSString
        var result = ""
        // kCFStringTokenizerAttributeLatinTranscription (0x08) returns hiragana for Japanese
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while !tokenType.isEmpty {
            if let attr = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, 0x08) {
                result += (attr as? String) ?? ""
            } else {
                let r = CFStringTokenizerGetCurrentTokenRange(tokenizer)
                result += nsText.substring(with: NSRange(location: r.location, length: r.length))
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        return result
    }

    // MARK: - 読みの正規化

    /// トークナイザに渡す前の下ごしらえ。数字をここでかなに開く。
    ///
    /// CFStringTokenizer は数字を含む日本語を壊す:
    ///   `0.5秒`→`5びょう` / `1,400円`→`400えん`（**桁が消える**）、`1人`→`1rén`（ピンイン混入）、
    ///   `4月`→`4つき`・`19日`→`19か`（助数詞の読み誤り）。
    /// 先にかなへ開くと `よんがつ` / `じゅうきゅうにち` と正しく読まれる。
    static func prepareForTokenization(_ text: String) -> String {
        readNumbers(text.precomposedStringWithCompatibilityMapping)
    }

    /// トークナイザが読みを付けられなかった部分を、音素表で拾える形に整える。
    ///
    /// - NFKC: トークナイザは `、`/`。`/`「` を**半角**形（`､`/`｡`/`｢`）で返すため、
    ///   全角に戻さないと音素表に当たらず**文の区切りがすべて消える**。半角カタカナも同時に畳む。
    /// - カタカナ→ひらがな: 読みが付かなかったカタカナ語をひらがなに寄せる。
    /// - ラテン文字・数字: そのままでは音素表に無く捨てられるので、日本語の読みに置き換える。
    ///   （数字は `prepareForTokenization` で開き済み。ここは取りこぼしの保険）
    static func normalizeReading(_ text: String) -> String {
        let folded = text.precomposedStringWithCompatibilityMapping
        let kana = katakanaToHiragana(folded)
        return readLatinRuns(readNumbers(kana))
    }

    /// カタカナをひらがなへ。長音符 `ー` と中黒 `・` はそのまま残す。
    static func katakanaToHiragana(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            // U+30A1(ァ) ... U+30F6(ヶ) を 0x60 下げると U+3041(ぁ) ... U+3096(ゖ) になる
            if scalar.value >= 0x30A1, scalar.value <= 0x30F6,
               let lowered = Unicode.Scalar(scalar.value - 0x60) {
                result.unicodeScalars.append(lowered)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// 数値リテラルを日本語の読み（ひらがな）に置き換える。
    static func readNumbers(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            guard chars[i].isASCIIDigit else {
                result.append(chars[i])
                i += 1
                continue
            }
            let (literal, next) = Self.scanNumber(chars, from: i)
            result += readNumber(literal)
            i = next
        }
        return result
    }

    /// ラテン文字の並びを日本語の読み（ひらがな）に置き換える。
    static func readLatinRuns(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            guard chars[i].isASCIILetter else {
                result.append(chars[i])
                i += 1
                continue
            }
            var j = i
            while j < chars.count, chars[j].isASCIILetter { j += 1 }
            result += readLatin(String(chars[i..<j]))
            i = j
        }
        return result
    }

    /// `i` から始まる数値リテラルを読み取る。桁区切りの `,` と小数点の `.` を、
    /// 数字が続く場合にかぎり数値の一部として取り込む（`1,400` / `3.14`）。
    private static func scanNumber(_ chars: [Character], from i: Int) -> (String, Int) {
        var literal = ""
        var j = i
        while j < chars.count {
            let c = chars[j]
            if c.isASCIIDigit {
                literal.append(c)
                j += 1
            } else if c == ",", j + 3 < chars.count,
                      chars[(j + 1)...(j + 3)].allSatisfy({ $0.isASCIIDigit }) {
                // 「1,400」の区切り。次が3桁の数字でなければ文の区切りとして残す。
                j += 1
            } else if c == ".", j + 1 < chars.count, chars[j + 1].isASCIIDigit,
                      !literal.contains(".") {
                literal.append(c)
                j += 1
            } else {
                break
            }
        }
        return (literal, j)
    }

    // MARK: - 数字の読み

    private static let digitReadings = ["", "いち", "に", "さん", "よん", "ご", "ろく", "なな", "はち", "きゅう"]

    /// 半角数字のリテラル（`1400` / `3.14`）を日本語の読みに変換する。
    static func readNumber(_ literal: String) -> String {
        let parts = literal.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integerReading = readInteger(String(parts.first ?? ""))
        guard parts.count == 2, !parts[1].isEmpty else { return integerReading }
        let fraction = parts[1].map { $0 == "0" ? "ぜろ" : digitReadings[Int(String($0)) ?? 0] }.joined()
        return integerReading + "てん" + fraction
    }

    /// 整数部の読み。4桁ごとに 万・億・兆 を付ける。兆を超える桁は1桁ずつ読む。
    static func readInteger(_ digits: String) -> String {
        let trimmed = String(digits.drop(while: { $0 == "0" }))
        if trimmed.isEmpty { return digits.isEmpty ? "" : "ぜろ" }
        // 兆（16桁）を超えたら位取りを諦めて1桁ずつ読む
        if trimmed.count > 16 {
            return trimmed.map { $0 == "0" ? "ぜろ" : digitReadings[Int(String($0)) ?? 0] }.joined()
        }

        let units = ["", "まん", "おく", "ちょう"]
        var groups: [Int] = []   // 下位から4桁ずつ
        var rest = Array(trimmed)
        while !rest.isEmpty {
            let head = max(0, rest.count - 4)
            groups.append(Int(String(rest[head...])) ?? 0)
            rest = Array(rest[..<head])
        }

        var result = ""
        for (index, group) in groups.enumerated().reversed() where group != 0 {
            result += joinUnit(readGroup(group), unit: units[index])
        }
        return result
    }

    /// 0...9999 を 千百十 で読む。300/600/800、3000/8000 の音便を含む。
    static func readGroup(_ value: Int) -> String {
        let thousands = (value / 1000) % 10
        let hundreds = (value / 100) % 10
        let tens = (value / 10) % 10
        let ones = value % 10

        var result = ""
        switch thousands {
        case 0: break
        case 1: result += "せん"
        case 3: result += "さんぜん"
        case 8: result += "はっせん"
        default: result += digitReadings[thousands] + "せん"
        }
        switch hundreds {
        case 0: break
        case 1: result += "ひゃく"
        case 3: result += "さんびゃく"
        case 6: result += "ろっぴゃく"
        case 8: result += "はっぴゃく"
        default: result += digitReadings[hundreds] + "ひゃく"
        }
        switch tens {
        case 0: break
        case 1: result += "じゅう"
        default: result += digitReadings[tens] + "じゅう"
        }
        result += digitReadings[ones]
        return result
    }

    /// 位の読みと単位をつなぐ。「いち＋ちょう」→「いっちょう」のような促音便を当てる。
    static func joinUnit(_ groupReading: String, unit: String) -> String {
        guard unit == "ちょう" else { return groupReading + unit }
        // いち/はち → い/は + っ、じゅう → じゅ + っ
        if groupReading.hasSuffix("いち") || groupReading.hasSuffix("はち")
            || groupReading.hasSuffix("じゅう") {
            return String(groupReading.dropLast()) + "っ" + unit
        }
        return groupReading + unit
    }

    // MARK: - ラテン文字の読み

    private static let letterReadings: [Character: String] = [
        "a": "えー", "b": "びー", "c": "しー", "d": "でぃー", "e": "いー",
        "f": "えふ", "g": "じー", "h": "えいち", "i": "あい", "j": "じぇー",
        "k": "けー", "l": "える", "m": "えむ", "n": "えぬ", "o": "おー",
        "p": "ぴー", "q": "きゅー", "r": "あーる", "s": "えす", "t": "てぃー",
        "u": "ゆー", "v": "ぶい", "w": "だぶりゅー", "x": "えっくす", "y": "わい",
        "z": "ぜっと",
    ]

    /// ラテン文字の並びを読みに変換する。
    ///
    /// トークナイザは既知の語（`Google`→ぐーぐる）や既知の略語（`PDF`→ぴーでぃーえふ）には
    /// 読みを付けてくれるので、ここに来るのは未知の語。
    /// 略語に見えるもの（短い or 全大文字）は1文字ずつアルファベット読みし、
    /// それ以外は ICU のローマ字→かな変換に任せる。読みが無いまま捨てると**無音になる**。
    static func readLatin(_ run: String) -> String {
        guard !run.isEmpty else { return "" }
        let isAcronym = run.count <= 4 || (run.count <= 8 && run == run.uppercased())
        if isAcronym {
            return run.lowercased().compactMap { letterReadings[$0] }.joined()
        }
        let mutable = NSMutableString(string: run) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformLatinHiragana, false)
        let transliterated = (mutable as NSMutableString) as String
        // 変換できずラテン文字が残るなら、無音を避けるためアルファベット読みに落とす
        if transliterated.contains(where: { $0.isASCIILetter }) {
            return run.lowercased().compactMap { letterReadings[$0] }.joined()
        }
        return katakanaToHiragana(transliterated.precomposedStringWithCompatibilityMapping)
    }

    // MARK: - Hiragana → Kokoro IPA (longest match)

    private static let table: [(String, String)] = {
        let raw: [(String, String)] = [
            // Compound kana (must come before single kana)
            ("きゃ", "kja"), ("きゅ", "kjɯ"), ("きょ", "kjo"),
            ("しゃ", "ɕa"), ("しゅ", "ɕɯ"), ("しょ", "ɕo"), ("しぇ", "ɕe"),
            ("ちゃ", "ʨa"), ("ちゅ", "ʨɯ"), ("ちょ", "ʨo"), ("ちぇ", "ʨe"),
            ("にゃ", "ɲa"), ("にゅ", "ɲɯ"), ("にょ", "ɲo"),
            ("ひゃ", "ça"), ("ひゅ", "çɯ"), ("ひょ", "ço"),
            ("みゃ", "mja"), ("みゅ", "mjɯ"), ("みょ", "mjo"),
            ("りゃ", "ɾja"), ("りゅ", "ɾjɯ"), ("りょ", "ɾjo"),
            ("ぎゃ", "ɡja"), ("ぎゅ", "ɡjɯ"), ("ぎょ", "ɡjo"),
            ("じゃ", "ʥa"), ("じゅ", "ʥɯ"), ("じょ", "ʥo"), ("じぇ", "ʥe"),
            ("びゃ", "bja"), ("びゅ", "bjɯ"), ("びょ", "bjo"),
            ("ぴゃ", "pja"), ("ぴゅ", "pjɯ"), ("ぴょ", "pjo"),
            ("ふぁ", "ɸa"), ("ふぃ", "ɸi"), ("ふぇ", "ɸe"), ("ふぉ", "ɸo"), ("ふゅ", "ɸjɯ"),
            ("てぃ", "ti"), ("でぃ", "di"), ("とぅ", "tɯ"), ("どぅ", "dɯ"),
            ("てゅ", "tjɯ"), ("でゅ", "djɯ"),
            ("つぁ", "ʦa"), ("つぃ", "ʦi"), ("つぇ", "ʦe"), ("つぉ", "ʦo"),
            ("うぁ", "wa"), ("うぃ", "wi"), ("うぇ", "we"), ("うぉ", "wo"),
            ("ゔぁ", "ba"), ("ゔぃ", "bi"), ("ゔぇ", "be"), ("ゔぉ", "bo"),

            // Single kana — vowels
            ("あ", "a"), ("い", "i"), ("う", "ɯ"), ("え", "e"), ("お", "o"),
            // か行
            ("か", "ka"), ("き", "ki"), ("く", "kɯ"), ("け", "ke"), ("こ", "ko"),
            // さ行
            ("さ", "sa"), ("し", "ɕi"), ("す", "sɯ"), ("せ", "se"), ("そ", "so"),
            // た行
            ("た", "ta"), ("ち", "ʨi"), ("つ", "ʦɯ"), ("て", "te"), ("と", "to"),
            // な行
            ("な", "na"), ("に", "ɲi"), ("ぬ", "nɯ"), ("ね", "ne"), ("の", "no"),
            // は行
            ("は", "ha"), ("ひ", "çi"), ("ふ", "ɸɯ"), ("へ", "he"), ("ほ", "ho"),
            // ま行
            ("ま", "ma"), ("み", "mi"), ("む", "mɯ"), ("め", "me"), ("も", "mo"),
            // や行
            ("や", "ja"), ("ゆ", "jɯ"), ("よ", "jo"),
            // ら行
            ("ら", "ɾa"), ("り", "ɾi"), ("る", "ɾɯ"), ("れ", "ɾe"), ("ろ", "ɾo"),
            // わ行
            ("わ", "wa"), ("ゐ", "i"), ("ゑ", "e"), ("を", "o"),
            // が行 — IPA の ɡ(U+0261)。ASCII の g(U+0067) は Kokoro の語彙に無い
            ("が", "ɡa"), ("ぎ", "ɡi"), ("ぐ", "ɡɯ"), ("げ", "ɡe"), ("ご", "ɡo"),
            // ざ行
            ("ざ", "za"), ("じ", "ʥi"), ("ず", "zɯ"), ("ぜ", "ze"), ("ぞ", "zo"),
            // だ行
            ("だ", "da"), ("ぢ", "ʥi"), ("づ", "ʣɯ"), ("で", "de"), ("ど", "do"),
            // ば行
            ("ば", "ba"), ("び", "bi"), ("ぶ", "bɯ"), ("べ", "be"), ("ぼ", "bo"),
            // ぱ行
            ("ぱ", "pa"), ("ぴ", "pi"), ("ぷ", "pɯ"), ("ぺ", "pe"), ("ぽ", "po"),
            // 小書きのかな（単独で現れた場合）
            ("ぁ", "a"), ("ぃ", "i"), ("ぅ", "ɯ"), ("ぇ", "e"), ("ぉ", "o"),
            ("ゃ", "ja"), ("ゅ", "jɯ"), ("ょ", "jo"), ("ゎ", "wa"),
            ("ゔ", "bɯ"),
            // 特殊
            ("ん", "ɴ"),
            ("っ", "ʔ"),   // 次の子音を前置 — 近似としてʔを使用
            ("ー", "ː"),   // 長音
            // 句読点 — トークナイザが返す半角形は normalizeReading の NFKC で全角に畳まれる
            ("、", " "), ("。", ". "), ("，", " "), ("．", ". "),
            ("！", "! "), ("？", "? "), ("「", " "), ("」", " "),
            ("『", " "), ("』", " "), ("（", " "), ("）", " "),
            ("【", " "), ("】", " "), ("〈", " "), ("〉", " "),
            ("・", " "), ("　", " "), ("…", "…"), ("‥", "…"),
        ]
        return raw.sorted { $0.0.count > $1.0.count }
    }()

    static func hiraganaToIPA(_ text: String) -> String {
        var result = ""
        var s = text
        while !s.isEmpty {
            var matched = false
            for (kana, ipa) in Self.table {
                if s.hasPrefix(kana) {
                    result += ipa
                    s = String(s.dropFirst(kana.count))
                    matched = true
                    break
                }
            }
            if !matched {
                // 未対応文字（記号・英数など）は句読点のみ通過
                let c = s.removeFirst()
                let pass = Set<Character>(";:,.!?—…\"() ")
                if pass.contains(c) { result += String(c) }
            }
        }
        return applyLongVowels(result).trimmingCharacters(in: .whitespaces)
    }

    /// 「おう」の並びを長音 `oː` に畳む。
    ///
    /// 「とうきょう」をそのまま `toɯkjoɯ` で渡すと語末に /u/ が立って「とうきょうう」に近い
    /// 不自然な音になる。日本語の「おう」は長音 `oː` なので畳む。
    /// 同一母音の連続（`aa`/`ii` など）は Kokoro 側でそのまま伸びた母音として鳴るので触らない
    /// （`県に行く`→`ɲii` のような形態素境界をまたぐ並びを壊さないため）。
    static func applyLongVowels(_ ipa: String) -> String {
        ipa.replacingOccurrences(of: "oɯ", with: "oː")
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetter: Bool { isASCII && isLetter }
}
