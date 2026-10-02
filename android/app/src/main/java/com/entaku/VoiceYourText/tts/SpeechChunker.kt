package com.entaku.VoiceYourText.tts

/**
 * 読み上げるテキストを文単位に分ける。
 *
 * Android の TextToSpeech には一時停止が無いので、文ごとに分けてキューに積み、
 * 何文目まで読んだかを覚えておいて再開時にそこから積み直す。
 * また TextToSpeech は1回に渡せる長さに上限がある（getMaxSpeechInputLength、通常 4000）ため、
 * 1文が長すぎる場合は maxLength ごとに切る。
 */
object SpeechChunker {
    private val sentenceEnd = Regex("""(?<=[。．！？!?\n])|(?<=\.)(?=\s)""")

    fun split(text: String, maxLength: Int = DEFAULT_MAX_LENGTH): List<String> {
        require(maxLength > 0)
        return text.split(sentenceEnd)
            .flatMap { it.chunked(maxLength) }
            .filter { it.isNotBlank() }
    }

    const val DEFAULT_MAX_LENGTH = 3000
}
