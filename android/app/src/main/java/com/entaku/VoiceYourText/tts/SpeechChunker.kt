package com.entaku.VoiceYourText.tts

/**
 * 読み上げるテキストを文単位に分ける。
 *
 * Android の TextToSpeech には一時停止が無いので、文ごとに分けてキューに積み、
 * 何文目まで読んだかを覚えておいて再開時にそこから積み直す。
 * また TextToSpeech は1回に渡せる長さに上限がある（getMaxSpeechInputLength、通常 4000）ため、
 * 1文が長すぎる場合は maxLength ごとに切る。
 */
/** 分けた1文と、元のテキスト上の開始位置（ハイライト位置の計算に使う） */
data class TextChunk(val text: String, val start: Int)

object SpeechChunker {
    private val sentenceEnd = Regex("""(?<=[。．！？!?\n])|(?<=\.)(?=\s)""")

    fun split(text: String, maxLength: Int = DEFAULT_MAX_LENGTH): List<String> =
        splitWithOffsets(text, maxLength).map { it.text }

    fun splitWithOffsets(text: String, maxLength: Int = DEFAULT_MAX_LENGTH): List<TextChunk> {
        require(maxLength > 0)
        val result = mutableListOf<TextChunk>()
        var offset = 0
        for (sentence in text.split(sentenceEnd)) {
            sentence.chunked(maxLength).forEach { piece ->
                if (piece.isNotBlank()) result += TextChunk(piece, offset)
                offset += piece.length
            }
        }
        return result
    }

    const val DEFAULT_MAX_LENGTH = 3000
}
