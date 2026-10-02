package com.entaku.VoiceYourText.tts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SpeechLanguageTest {

    @Test
    fun iOSと同じ13言語を選べる() {
        // iOS Setting.swift availableLanguages の言語コード
        val ios = setOf("en", "ja", "de", "es", "tr", "fr", "vi", "th", "ko", "it", "zh", "pt", "ru")
        assertEquals(ios, SpeechLanguage.ALL.map { it.code }.toSet())
        assertEquals(13, SpeechLanguage.ALL.size)
    }

    @Test
    fun 言語コードから復元できる() {
        assertEquals(SpeechLanguage.THAI, SpeechLanguage.fromCode("th"))
        assertNull(SpeechLanguage.fromCode("xx"))
        assertNull(SpeechLanguage.fromCode(null))
    }
}
