package com.entaku.VoiceYourText.voicevox

import com.entaku.VoiceYourText.tts.TextRange
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VoicevoxTextChunkerTest {

    @Test
    fun splitsBySentenceAndKeepsRanges() {
        val text = "こんにちは。「元気です！」\n  さようなら"
        val chunks = VoicevoxTextChunker.chunks(text)
        assertEquals(listOf("こんにちは。", "「元気です！」", "さようなら"), chunks.map { it.text })
        chunks.forEach { assertEquals(it.text, text.substring(it.range.start, it.range.end)) }
    }

    @Test
    fun keepsClosingBracketAndRepeatedTerminators() {
        val chunks = VoicevoxTextChunker.chunks("本当？！」次。")
        assertEquals(listOf("本当？！」", "次。"), chunks.map { it.text })
    }

    @Test
    fun skipsSymbolOnlyLines() {
        val chunks = VoicevoxTextChunker.chunks("――\n・・・\n本文")
        assertEquals(listOf("本文"), chunks.map { it.text })
        assertEquals(TextRange(7, 2), chunks[0].range)
    }

    @Test
    fun splitsLongSentenceAtCommaWithinLimit() {
        val text = "あ".repeat(8) + "、" + "い".repeat(8) + "。"
        val chunks = VoicevoxTextChunker.chunks(text, maxChars = 10)
        assertEquals(listOf("あ".repeat(8) + "、", "い".repeat(8) + "。"), chunks.map { it.text })
    }

    @Test
    fun hardSplitsWhenNoBreakCharacter() {
        val chunks = VoicevoxTextChunker.chunks("あ".repeat(25), maxChars = 10)
        assertEquals(listOf(10, 10, 5), chunks.map { it.text.length })
        assertTrue(chunks.all { it.text.codePointCount(0, it.text.length) <= 10 })
    }

    @Test
    fun countsSurrogatePairsAsOneCharacter() {
        val text = "𠮷".repeat(12)
        val chunks = VoicevoxTextChunker.chunks(text, maxChars = 10)
        assertEquals(listOf(10, 2), chunks.map { it.text.codePointCount(0, it.text.length) })
        assertEquals(text, chunks.joinToString("") { it.text })
    }
}
