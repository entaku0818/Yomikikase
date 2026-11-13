package com.entaku.VoiceYourText.kokoro

import org.junit.Assert.*
import org.junit.Test

class KokoroTextChunkerTest {
    @Test fun shortSentencesShareContext() {
        val text = "こんにちは。今日はいい天気です。公園へ行きましょう。"
        val chunks = KokoroTextChunker.chunks(text)
        assertEquals(listOf(text), chunks.map { it.text })
    }

    @Test fun longTextKeepsOriginalRangesAndEveryWord() {
        val text = "朝の公園で、鳥の声を聞きました。ゆっくり歩くのもいいですね。".repeat(20)
        val chunks = KokoroTextChunker.chunks(text)
        assertTrue(chunks.size > 1)
        assertEquals(text, chunks.joinToString("") { it.text })
        chunks.forEach {
            assertTrue(it.text.length <= 120)
            assertEquals(it.text, text.substring(it.range.start, it.range.start + it.range.length))
        }
    }

    @Test fun symbolsOnlyDoNotCreateSpeech() {
        assertTrue(KokoroTextChunker.chunks("……\n　").isEmpty())
    }
}
