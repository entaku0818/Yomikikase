package com.entaku.VoiceYourText.tts

/**
 * 読み上げ前にテキストを整える（iOS `Features/Player/SpeechTextPreprocessor.swift` の移植）。
 *
 * 1. ユーザー辞書の読み方を適用する（全言語）
 * 2. 日本語のときだけ、英略語・単位・桁区切りカンマ・記号を読みやすい表記に置き換える
 * 3. PDF などで紙面の行幅で折り返された改行を詰める
 *
 * 置換するとハイライト位置がずれるので、読み上げ用テキスト（spoken）から元テキスト（original）へ
 * 範囲を逆引きできる対応表（segments）を一緒に返す。位置は Kotlin の String と同じ UTF-16 単位。
 */
data class TextRange(val start: Int, val length: Int) {
    val end: Int get() = start + length
}

data class PreparedSpeechText(
    val original: String,
    val spoken: String,
    /** spoken の位置昇順。spoken / original の双方を隙間なく覆う */
    val segments: List<Segment>,
) {
    data class Segment(
        val spoken: TextRange,
        val original: TextRange,
        /** 置換が起きた区間か（false なら 1:1 対応） */
        val isReplaced: Boolean,
    )

    val isIdentity: Boolean get() = segments.none { it.isReplaced }

    /**
     * 読み上げ用テキスト上の範囲を元テキスト上の範囲に変換する。
     * 置換区間に少しでも重なれば置換元の語全体を返す（「ピーディーエフ」の途中なら「PDF」全体）。
     */
    fun originalRange(range: TextRange): TextRange? {
        var lower = Int.MAX_VALUE
        var upper = Int.MIN_VALUE
        for (segment in segments) {
            if (!intersects(segment.spoken, range)) continue
            if (segment.isReplaced) {
                lower = minOf(lower, segment.original.start)
                upper = maxOf(upper, segment.original.end)
            } else {
                val offset = range.start - segment.spoken.start
                val start = segment.original.start + maxOf(0, offset)
                val overlapEnd = minOf(range.end, segment.spoken.end)
                val end = segment.original.start + (overlapEnd - segment.spoken.start)
                lower = minOf(lower, start)
                upper = maxOf(upper, maxOf(start, end))
            }
        }
        if (lower == Int.MAX_VALUE || upper < lower) return null
        return TextRange(lower, upper - lower)
    }

    /** ゼロ長の範囲も「その位置に触れている」とみなす */
    private fun intersects(a: TextRange, b: TextRange): Boolean =
        if (a.length == 0 || b.length == 0) a.start <= b.end && b.start <= a.end
        else a.start < b.end && b.start < a.end

    companion object {
        fun identity(text: String): PreparedSpeechText = PreparedSpeechText(
            original = text,
            spoken = text,
            segments = if (text.isEmpty()) emptyList()
            else listOf(Segment(TextRange(0, text.length), TextRange(0, text.length), isReplaced = false)),
        )
    }
}

object SpeechTextPreprocessor {

    data class Rule(val pattern: Regex, val replacement: String)

    private data class Candidate(val range: TextRange, val replacement: String, val priority: Int)

    /**
     * @param languageCode 読み上げ言語（"ja" / "ja-JP" / "en" など）。日本語以外では日本語向けルールを使わない
     * @param readings ユーザー辞書の（単語, 読み）。全言語で適用する
     */
    fun prepare(
        text: String,
        languageCode: String?,
        readings: List<Pair<String, String>> = emptyList(),
    ): PreparedSpeechText {
        if (text.isEmpty()) return PreparedSpeechText.identity(text)

        val candidates = mutableListOf<Candidate>()

        // 優先度0: ユーザー辞書。長い単語から見て、短い単語が長い単語の一部を食わないようにする
        readings.sortedByDescending { it.first.length }.forEach { (word, reading) ->
            if (word.isEmpty() || word == reading) return@forEach
            var from = text.indexOf(word)
            while (from >= 0) {
                candidates += Candidate(TextRange(from, word.length), reading, 0)
                from = text.indexOf(word, from + word.length)
            }
        }

        val isJapanese = languageCode?.lowercase()?.substringBefore('-')?.substringBefore('_') == "ja"

        // 優先度1: 日本語のときだけ働くルール
        if (isJapanese) {
            JAPANESE_RULES.forEach { rule -> candidates += matches(rule, text, 1) }
        }

        // 優先度2: 改行の整形（全言語）
        newlineRules(isJapanese).forEach { rule -> candidates += matches(rule, text, 2) }

        if (candidates.isEmpty()) return PreparedSpeechText.identity(text)

        // 重なりの解消: 位置が早い順 → 優先度が高い順 → 長い順に採用し、採用済みと重なるものは捨てる
        candidates.sortWith(
            compareBy<Candidate> { it.range.start }
                .thenBy { it.priority }
                .thenByDescending { it.range.length }
        )
        val accepted = mutableListOf<Candidate>()
        var consumedUpTo = 0
        for (candidate in candidates) {
            if (candidate.range.start < consumedUpTo) continue
            accepted += candidate
            consumedUpTo = candidate.range.end
        }

        val spoken = StringBuilder()
        val segments = mutableListOf<PreparedSpeechText.Segment>()
        var cursor = 0
        for (item in accepted) {
            if (item.range.start > cursor) {
                val plain = text.substring(cursor, item.range.start)
                segments += PreparedSpeechText.Segment(
                    TextRange(spoken.length, plain.length), TextRange(cursor, plain.length), isReplaced = false
                )
                spoken.append(plain)
            }
            segments += PreparedSpeechText.Segment(
                TextRange(spoken.length, item.replacement.length), item.range, isReplaced = true
            )
            spoken.append(item.replacement)
            cursor = item.range.end
        }
        if (cursor < text.length) {
            val tail = text.substring(cursor)
            segments += PreparedSpeechText.Segment(
                TextRange(spoken.length, tail.length), TextRange(cursor, tail.length), isReplaced = false
            )
            spoken.append(tail)
        }
        return PreparedSpeechText(text, spoken.toString(), segments)
    }

    private fun matches(rule: Rule, text: String, priority: Int): List<Candidate> =
        rule.pattern.findAll(text)
            .filter { it.range.last >= it.range.first }
            .map { Candidate(TextRange(it.range.first, it.range.last - it.range.first + 1), rule.replacement, priority) }
            .toList()

    /**
     * 日本語の文中で誤読されやすい表記。
     * 英略語は前後がアルファベットでないときだけ、単位は直前が数字のときだけ置換する。
     */
    val JAPANESE_RULES: List<Rule> = buildList {
        // 桁区切りカンマを外す（"1,234" → "1234"）。3桁区切りの形だけ
        add(Rule(Regex("""(?<=[0-9]),(?=[0-9]{3}(?![0-9]))"""), ""))

        listOf(
            "iOS" to "アイオーエス", "Wi-Fi" to "ワイファイ", "WiFi" to "ワイファイ", "EPUB" to "イーパブ",
            "HTML" to "エイチティーエムエル", "JSON" to "ジェイソン", "PDF" to "ピーディーエフ", "URL" to "ユーアールエル",
            "API" to "エーピーアイ", "CPU" to "シーピーユー", "GPU" to "ジーピーユー", "USB" to "ユーエスビー",
            "FAQ" to "エフエーキュー", "SNS" to "エスエヌエス", "OCR" to "オーシーアール", "CSV" to "シーエスブイ",
            "DVD" to "ディーブイディー", "TTS" to "ティーティーエス", "AI" to "エーアイ", "ID" to "アイディー",
            "OS" to "オーエス", "PC" to "ピーシー", "TV" to "ティービー", "UI" to "ユーアイ", "UX" to "ユーエックス",
            "CD" to "シーディー",
        ).forEach { (token, reading) ->
            add(Rule(Regex("""(?<![A-Za-z])${Regex.escape(token)}(?![A-Za-z])"""), reading))
        }

        listOf(
            "km" to "キロメートル", "cm" to "センチメートル", "mm" to "ミリメートル", "kg" to "キログラム",
            "mg" to "ミリグラム", "ml" to "ミリリットル", "mL" to "ミリリットル", "MHz" to "メガヘルツ",
            "kHz" to "キロヘルツ", "MB" to "メガバイト", "GB" to "ギガバイト", "KB" to "キロバイト", "TB" to "テラバイト",
        ).forEach { (token, reading) ->
            add(Rule(Regex("""(?<=[0-9０-９])${Regex.escape(token)}(?![A-Za-z])"""), reading))
        }

        add(Rule(Regex("""(?<=[0-9０-９])[%％]"""), "パーセント"))
        add(Rule(Regex("""(?<=[0-9０-９])(?:℃|°C)"""), "度"))
    }

    /**
     * 改行の整形。PDF や EPUB は紙面の行幅で折り返されていて文の途中に改行が入るので、
     * 「文が続いている」と確実に言える改行だけを詰める。空行・句点や閉じ括弧で終わる行・箇条書きは触らない。
     */
    fun newlineRules(japanese: Boolean): List<Rule> = buildList {
        // 英語のハイフネーション解除（"narra-\ntor" → "narrator"）
        add(Rule(Regex("""(?<=[A-Za-z])-\n(?=[a-z])"""), ""))
        if (japanese) {
            val jaBody = "ぁ-んァ-ヴー一-龥々〆ヵヶ、「『（【〔［"
            val jaTail = "ぁ-んァ-ヴー一-龥々〆ヵヶ、"
            add(Rule(Regex("""(?<=[$jaTail])\n(?=[$jaBody])"""), ""))
        } else {
            add(Rule(Regex("""(?<=[a-z,])\n(?=[a-z])"""), " "))
        }
    }
}
