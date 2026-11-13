package com.entaku.VoiceYourText.kokoro

import com.atilika.kuromoji.ipadic.Tokenizer
import java.text.Normalizer

/** Prototype G2P: Kuromoji readings + the app's iOS kana/IPA table.
 * Unknown characters are rejected, never silently removed. Numerals are read digit by digit.
 */
class JapanesePhonemes {
    private val tokenizer = Tokenizer()
    fun convert(text: String): String {
        val normalized = Normalizer.normalize(text, Normalizer.Form.NFKC)
        val readings = tokenizer.tokenize(normalized).joinToString("") { token ->
            token.pronunciation.takeUnless { it == "*" || it.isEmpty() } ?: token.surface
        }
        return fromReading(readings)
    }

    companion object {
        private val digits = listOf("ぜろ", "いち", "に", "さん", "よん", "ご", "ろく", "なな", "はち", "きゅう")
        private val letters = listOf("えー", "びー", "しー", "でぃー", "いー", "えふ", "じー", "えいち", "あい", "じぇー", "けー", "える", "えむ", "えぬ", "おー", "ぴー", "きゅー", "あーる", "えす", "てぃー", "ゆー", "ぶい", "だぶりゅー", "えっくす", "わい", "ぜっと")
        private val table = listOf(
            "きゃ" to "kja",
            "きゅ" to "kjɯ",
            "きょ" to "kjo",
            "しゃ" to "ɕa",
            "しゅ" to "ɕɯ",
            "しょ" to "ɕo",
            "しぇ" to "ɕe",
            "ちゃ" to "ʨa",
            "ちゅ" to "ʨɯ",
            "ちょ" to "ʨo",
            "ちぇ" to "ʨe",
            "にゃ" to "ɲa",
            "にゅ" to "ɲɯ",
            "にょ" to "ɲo",
            "ひゃ" to "ça",
            "ひゅ" to "çɯ",
            "ひょ" to "ço",
            "みゃ" to "mja",
            "みゅ" to "mjɯ",
            "みょ" to "mjo",
            "りゃ" to "ɾja",
            "りゅ" to "ɾjɯ",
            "りょ" to "ɾjo",
            "ぎゃ" to "ɡja",
            "ぎゅ" to "ɡjɯ",
            "ぎょ" to "ɡjo",
            "じゃ" to "ʥa",
            "じゅ" to "ʥɯ",
            "じょ" to "ʥo",
            "じぇ" to "ʥe",
            "びゃ" to "bja",
            "びゅ" to "bjɯ",
            "びょ" to "bjo",
            "ぴゃ" to "pja",
            "ぴゅ" to "pjɯ",
            "ぴょ" to "pjo",
            "ふぁ" to "ɸa",
            "ふぃ" to "ɸi",
            "ふぇ" to "ɸe",
            "ふぉ" to "ɸo",
            "ふゅ" to "ɸjɯ",
            "てぃ" to "ti",
            "でぃ" to "di",
            "とぅ" to "tɯ",
            "どぅ" to "dɯ",
            "てゅ" to "tjɯ",
            "でゅ" to "djɯ",
            "つぁ" to "ʦa",
            "つぃ" to "ʦi",
            "つぇ" to "ʦe",
            "つぉ" to "ʦo",
            "うぁ" to "wa",
            "うぃ" to "wi",
            "うぇ" to "we",
            "うぉ" to "wo",
            "ゔぁ" to "ba",
            "ゔぃ" to "bi",
            "ゔぇ" to "be",
            "ゔぉ" to "bo",
            "あ" to "a",
            "い" to "i",
            "う" to "ɯ",
            "え" to "e",
            "お" to "o",
            "か" to "ka",
            "き" to "ki",
            "く" to "kɯ",
            "け" to "ke",
            "こ" to "ko",
            "さ" to "sa",
            "し" to "ɕi",
            "す" to "sɯ",
            "せ" to "se",
            "そ" to "so",
            "た" to "ta",
            "ち" to "ʨi",
            "つ" to "ʦɯ",
            "て" to "te",
            "と" to "to",
            "な" to "na",
            "に" to "ɲi",
            "ぬ" to "nɯ",
            "ね" to "ne",
            "の" to "no",
            "は" to "ha",
            "ひ" to "çi",
            "ふ" to "ɸɯ",
            "へ" to "he",
            "ほ" to "ho",
            "ま" to "ma",
            "み" to "mi",
            "む" to "mɯ",
            "め" to "me",
            "も" to "mo",
            "や" to "ja",
            "ゆ" to "jɯ",
            "よ" to "jo",
            "ら" to "ɾa",
            "り" to "ɾi",
            "る" to "ɾɯ",
            "れ" to "ɾe",
            "ろ" to "ɾo",
            "わ" to "wa",
            "ゐ" to "i",
            "ゑ" to "e",
            "を" to "o",
            "が" to "ɡa",
            "ぎ" to "ɡi",
            "ぐ" to "ɡɯ",
            "げ" to "ɡe",
            "ご" to "ɡo",
            "ざ" to "za",
            "じ" to "ʥi",
            "ず" to "zɯ",
            "ぜ" to "ze",
            "ぞ" to "zo",
            "だ" to "da",
            "ぢ" to "ʥi",
            "づ" to "ʣɯ",
            "で" to "de",
            "ど" to "do",
            "ば" to "ba",
            "び" to "bi",
            "ぶ" to "bɯ",
            "べ" to "be",
            "ぼ" to "bo",
            "ぱ" to "pa",
            "ぴ" to "pi",
            "ぷ" to "pɯ",
            "ぺ" to "pe",
            "ぽ" to "po",
            "ぁ" to "a",
            "ぃ" to "i",
            "ぅ" to "ɯ",
            "ぇ" to "e",
            "ぉ" to "o",
            "ゃ" to "ja",
            "ゅ" to "jɯ",
            "ょ" to "jo",
            "ゎ" to "wa",
            "ゔ" to "bɯ",
            "ん" to "ɴ",
            "っ" to "ʔ",
            "ー" to "ː",
            "、" to " ",
            "。" to ". ",
            "，" to " ",
            "．" to ". ",
            "！" to "! ",
            "？" to "? ",
            "「" to " ",
            "」" to " ",
            "『" to " ",
            "』" to " ",
            "（" to " ",
            "）" to " ",
            "【" to " ",
            "】" to " ",
            "〈" to " ",
            "〉" to " ",
            "・" to " ",
            "　" to " ",
            "…" to "…",
            "‥" to "…"
        ).sortedByDescending { it.first.length }

        internal fun fromReading(input: String): String {
            val kana = buildString {
                Normalizer.normalize(input, Normalizer.Form.NFKC).forEach { c ->
                    when {
                        c in 'ァ'..'ヶ' -> append((c.code - 0x60).toChar())
                        c in '0'..'9' -> append(digits[c - '0'])
                        c.lowercaseChar() in 'a'..'z' -> append(letters[c.lowercaseChar() - 'a'])
                        else -> append(c)
                    }
                }
            }
            val ipa = StringBuilder()
            var i = 0
            while (i < kana.length) {
                val match = table.firstOrNull { kana.startsWith(it.first, i) }
                if (match != null) {
                    ipa.append(match.second)
                    i += match.first.length
                } else {
                    val c = kana[i++]
                    require(c.isWhitespace() || c in ";:,.!?—…\"()") { "読みを取得できない文字: $c" }
                    ipa.append(if (c.isWhitespace()) ' ' else c)
                }
            }
            return ipa.toString().replace("oɯ", "oː").trim()
        }
    }
}
