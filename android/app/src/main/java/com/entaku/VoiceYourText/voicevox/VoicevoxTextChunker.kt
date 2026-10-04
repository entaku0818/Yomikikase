package com.entaku.VoiceYourText.voicevox

import com.entaku.VoiceYourText.tts.TextRange

/**
 * キャラ音声（VOICEVOX）用に文章を文ごとに分ける（iOS VoicevoxTextChunker と同じ規則）。
 *
 * サーバーは1回300字までしか受け付けず、1文ずつ作って最初の文ができたら再生を始めるため、
 * 文末（。！？ など）と改行で区切る。元の文章の中の位置を持たせて、再生中のハイライトに使う。
 */
object VoicevoxTextChunker {
    data class Chunk(val text: String, val range: TextRange)

    /** サーバー側の MAX_REQUEST_CHARS と合わせる */
    const val DEFAULT_MAX_CHARS = 300

    private val terminators = setOf('。', '！', '？', '!', '?', '…', '\n')
    /** 文末の直後に続く閉じ括弧は前の文に含める（「〜です。」の 」 など） */
    private val trailingClosers = setOf('」', '』', '）', ')', '】', '〉', '》', '"', '”', '’')
    /** 長すぎる文を途中で切るときの候補 */
    private val softBreaks = setOf('、', '，', ',', '；', ';', '：', ':', ' ', '　')

    fun chunks(text: String, maxChars: Int = DEFAULT_MAX_CHARS): List<Chunk> {
        val result = mutableListOf<Chunk>()
        var sentenceStart = 0
        var index = 0
        while (index < text.length) {
            val c = text[index]
            index++
            if (c !in terminators) continue
            while (index < text.length &&
                (text[index] in trailingClosers || (c != '\n' && text[index] in terminators && text[index] != '\n'))
            ) {
                index++
            }
            appendSentence(text, sentenceStart, index, maxChars, result)
            sentenceStart = index
        }
        if (sentenceStart < text.length) appendSentence(text, sentenceStart, text.length, maxChars, result)
        return result
    }

    private fun appendSentence(text: String, from: Int, to: Int, maxChars: Int, result: MutableList<Chunk>) {
        var start = from
        while (start < to) {
            var end = to
            if (text.codePointCount(start, end) > maxChars) end = splitPoint(text, start, to, maxChars)
            appendTrimmed(text, start, end, result)
            start = end
        }
    }

    /** maxChars 以内で、なるべく読点などの直後で切る位置 */
    private fun splitPoint(text: String, start: Int, limit: Int, maxChars: Int): Int {
        var count = 0
        var hardLimit = start
        var lastSoft: Int? = null
        var index = start
        while (index < limit) {
            val next = index + Character.charCount(text.codePointAt(index))
            count++
            if (count > maxChars) break
            hardLimit = next
            if (text[index] in softBreaks) lastSoft = next
            index = next
        }
        return lastSoft ?: hardLimit
    }

    private fun appendTrimmed(text: String, from: Int, to: Int, result: MutableList<Chunk>) {
        var lower = from
        var upper = to
        while (lower < upper && text[lower].isWhitespace()) lower++
        while (upper > lower && text[upper - 1].isWhitespace()) upper--
        if (lower >= upper) return
        val piece = text.substring(lower, upper)
        // 記号だけの行（「――」「・・・」など）は読む内容がないので送らない（文字数を使わせない）
        if (piece.codePoints().noneMatch(Character::isLetterOrDigit)) return
        result += Chunk(piece, TextRange(lower, upper - lower))
    }
}
