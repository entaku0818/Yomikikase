package com.entaku.VoiceYourText.dictionary

import com.entaku.VoiceYourText.tts.SpeechTextPreprocessor
import org.junit.Assert.assertEquals
import org.junit.Test

class UserDictionaryStoreTest {

    @Test
    fun 保存形式は往復で同じになる() {
        val entries = listOf(
            UserDictionaryEntry("1", "生田", "いくた", 10L),
            UserDictionaryEntry("2", "タブ\tと\n改行と\\", "よみ", 20L),
        )
        assertEquals(entries, UserDictionaryStore.decode(UserDictionaryStore.encode(entries)))
    }

    @Test
    fun 壊れた行は読み飛ばす() {
        assertEquals(emptyList<UserDictionaryEntry>(), UserDictionaryStore.decode("壊れた行\n"))
    }

    @Test
    fun 登録した読み方で読み上げ用テキストを作る() {
        val spoken = SpeechTextPreprocessor.prepare("生田さんがPDFを読む", "ja", listOf("生田" to "いくた")).spoken
        assertEquals("いくたさんがピーディーエフを読む", spoken)
    }
}
