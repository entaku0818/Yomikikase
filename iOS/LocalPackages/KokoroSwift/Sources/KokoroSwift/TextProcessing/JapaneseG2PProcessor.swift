import Foundation
import MLXUtilsLibrary

/// Japanese G2P processor.
/// Pipeline: Japanese text → hiragana (via CFStringTokenizer) → Kokoro IPA phonemes
final class JapaneseG2PProcessor: G2PProcessor {

    func setLanguage(_ language: Language) throws {
        guard language == .ja else { throw G2PProcessorError.unsupportedLanguage }
    }

    func process(input: String) throws -> (String, [MToken]?) {
        let hiragana = toHiragana(input)
        let ipa = hiraganaToIPA(hiragana)
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
                result += (attr as! String)
            } else {
                let r = CFStringTokenizerGetCurrentTokenRange(tokenizer)
                result += nsText.substring(with: NSRange(location: r.location, length: r.length))
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        return result
    }

    // MARK: - Hiragana → Kokoro IPA (longest match)

    private static let table: [(String, String)] = {
        let raw: [(String, String)] = [
            // Compound kana (must come before single kana)
            ("きゃ","kja"),("きゅ","kjɯ"),("きょ","kjo"),
            ("しゃ","ɕa"),("しゅ","ɕɯ"),("しょ","ɕo"),
            ("ちゃ","ʨa"),("ちゅ","ʨɯ"),("ちょ","ʨo"),
            ("にゃ","ɲa"),("にゅ","ɲɯ"),("にょ","ɲo"),
            ("ひゃ","ça"),("ひゅ","çɯ"),("ひょ","ço"),
            ("みゃ","mja"),("みゅ","mjɯ"),("みょ","mjo"),
            ("りゃ","ɾja"),("りゅ","ɾjɯ"),("りょ","ɾjo"),
            ("ぎゃ","gja"),("ぎゅ","gjɯ"),("ぎょ","gjo"),
            ("じゃ","ʥa"),("じゅ","ʥɯ"),("じょ","ʥo"),
            ("びゃ","bja"),("びゅ","bjɯ"),("びょ","bjo"),
            ("ぴゃ","pja"),("ぴゅ","pjɯ"),("ぴょ","pjo"),
            ("ふぁ","ɸa"),("ふぃ","ɸi"),("ふぇ","ɸe"),("ふぉ","ɸo"),
            ("てぃ","ti"),("でぃ","di"),("とぅ","tɯ"),("どぅ","dɯ"),
            ("うぁ","wa"),("うぃ","wi"),("うぇ","we"),("うぉ","wo"),

            // Single kana — vowels
            ("あ","a"),("い","i"),("う","ɯ"),("え","e"),("お","o"),
            // か行
            ("か","ka"),("き","ki"),("く","kɯ"),("け","ke"),("こ","ko"),
            // さ行
            ("さ","sa"),("し","ɕi"),("す","sɯ"),("せ","se"),("そ","so"),
            // た行
            ("た","ta"),("ち","ʨi"),("つ","ʦɯ"),("て","te"),("と","to"),
            // な行
            ("な","na"),("に","ɲi"),("ぬ","nɯ"),("ね","ne"),("の","no"),
            // は行
            ("は","ha"),("ひ","çi"),("ふ","ɸɯ"),("へ","he"),("ほ","ho"),
            // ま行
            ("ま","ma"),("み","mi"),("む","mɯ"),("め","me"),("も","mo"),
            // や行
            ("や","ja"),("ゆ","jɯ"),("よ","jo"),
            // ら行
            ("ら","ɾa"),("り","ɾi"),("る","ɾɯ"),("れ","ɾe"),("ろ","ɾo"),
            // わ行
            ("わ","wa"),("ゐ","i"),("ゑ","e"),("を","o"),
            // が行
            ("が","ga"),("ぎ","gi"),("ぐ","gɯ"),("げ","ge"),("ご","go"),
            // ざ行
            ("ざ","za"),("じ","ʥi"),("ず","zɯ"),("ぜ","ze"),("ぞ","zo"),
            // だ行
            ("だ","da"),("ぢ","ʥi"),("づ","ʣɯ"),("で","de"),("ど","do"),
            // ば行
            ("ば","ba"),("び","bi"),("ぶ","bɯ"),("べ","be"),("ぼ","bo"),
            // ぱ行
            ("ぱ","pa"),("ぴ","pi"),("ぷ","pɯ"),("ぺ","pe"),("ぽ","po"),
            // 特殊
            ("ん","ɴ"),
            ("っ","ʔ"),   // 次の子音を前置 — 近似としてʔを使用
            ("ー","ː"),   // 長音
            // 句読点
            ("、"," "),("。",". "),("，"," "),("．",". "),
            ("！","! "),("？","? "),("「"," "),("」"," "),
            ("　"," "),("…","…"),
        ]
        return raw.sorted { $0.0.count > $1.0.count }
    }()

    private func hiraganaToIPA(_ text: String) -> String {
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
        return result.trimmingCharacters(in: .whitespaces)
    }
}
