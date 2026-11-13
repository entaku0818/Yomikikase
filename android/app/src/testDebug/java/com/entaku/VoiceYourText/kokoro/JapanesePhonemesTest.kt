package com.entaku.VoiceYourText.kokoro

import org.junit.Assert.*
import org.junit.Test

class JapanesePhonemesTest {
    @Test fun longInputIsBoundedWithoutLosingPhonemes() {
        val text = "koɴɲiʨiha. ".repeat(40)
        val chunks = KokoroPrototype.chunks(text)
        assertEquals(text.trim(), chunks.joinToString("").trim())
        assertTrue(chunks.all { it.length <= 120 })
        assertTrue(chunks.size > 1)
    }
    @Test fun kanjiReadingsProducePhonemes() {
        val result = JapanesePhonemes().convert("今日は東京の図書館で本を読みます。")
        assertTrue(result.contains("toːkjoː"))
        assertTrue(result.endsWith("."))
        assertFalse(result.any { it in '\u4e00'..'\u9fff' })
    }
    @Test fun kanaAndLongVowelsMatchIOS() {
        assertEquals("ɡakkoː", JapanesePhonemes.fromReading("ガッコウ").replace("ʔ", "k"))
        assertEquals("ɕaɕiɴ", JapanesePhonemes.fromReading("ｼｬｼﾝ"))
        assertEquals("iʨiɲisaɴ", JapanesePhonemes.fromReading("123"))
    }
    @Test(expected = IllegalArgumentException::class)
    fun unsupportedCharactersAreNeverSilentlyDropped() {
        JapanesePhonemes.fromReading("テスト😀")
    }
}
