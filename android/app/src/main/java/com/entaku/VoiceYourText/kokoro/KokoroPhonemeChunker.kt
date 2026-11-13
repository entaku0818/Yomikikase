package com.entaku.VoiceYourText.kokoro

import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/** Split after Japanese G2P, keeping every phoneme and pause in order. */
internal object KokoroPhonemeChunker {
    // Retain the prototype's measured memory budget instead of using the model's 510-token limit.
    const val MAX_LENGTH = 120
    private const val MIN_LENGTH = 20
    private const val SENTENCE_ENDS = ".!?…"
    private const val PHRASE_ENDS = ",;:—"
    private const val CLOSING_MARKS = "\"'”’)]}」』"

    fun chunks(phonemes: String): List<String> {
        val result = mutableListOf<String>()
        var start = 0
        while (phonemes.length - start > MAX_LENGTH) {
            val limit = minOf(start + MAX_LENGTH, phonemes.length - MIN_LENGTH)
            val end = boundary(phonemes, start, limit, sentenceOnly = true)
                ?: boundary(phonemes, start, limit, sentenceOnly = false)
                ?: (start + minOf(MAX_LENGTH, (phonemes.length - start) / 2))
            result += phonemes.substring(start, end)
            start = end
        }
        if (start < phonemes.length) result += phonemes.substring(start)
        return result
    }

    suspend fun synthesize(phonemes: String, generate: suspend (String) -> Unit): Int {
        currentCoroutineContext().ensureActive()
        val chunks = chunks(phonemes)
        for (chunk in chunks) {
            currentCoroutineContext().ensureActive()
            generate(chunk)
            currentCoroutineContext().ensureActive()
        }
        return chunks.size
    }

    private fun boundary(text: String, start: Int, limit: Int, sentenceOnly: Boolean): Int? {
        var lastEnd: Int? = null
        for (index in start until limit) {
            val character = text[index]
            val matches = if (sentenceOnly) character in SENTENCE_ENDS
                else character in PHRASE_ENDS || character.isWhitespace()
            if (!matches) continue
            var end = index + 1
            while (end < text.length && (text[end] in SENTENCE_ENDS || text[end] in CLOSING_MARKS || text[end].isWhitespace())) {
                end++
                if (end > limit) break
            }
            if (end in (start + MIN_LENGTH)..limit) lastEnd = end
        }
        return lastEnd
    }
}
