package com.entaku.VoiceYourText.kokoro

import com.entaku.VoiceYourText.tts.TextRange
import com.entaku.VoiceYourText.voicevox.VoicevoxTextChunker

/** Keep neighboring short sentences together so inference has context for phrasing. */
object KokoroTextChunker {
    fun chunks(text: String): List<VoicevoxTextChunker.Chunk> {
        val sentences = VoicevoxTextChunker.chunks(text, maxChars = 120)
        val result = mutableListOf<VoicevoxTextChunker.Chunk>()
        var start = -1
        var end = 0
        fun append() {
            if (start >= 0) result += VoicevoxTextChunker.Chunk(text.substring(start, end), TextRange(start, end - start))
        }
        for (sentence in sentences) {
            val nextEnd = sentence.range.start + sentence.range.length
            if (start >= 0 && nextEnd - start > 120) {
                append()
                start = -1
            }
            if (start < 0) start = sentence.range.start
            end = nextEnd
        }
        append()
        return result
    }
}
