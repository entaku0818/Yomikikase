package com.entaku.VoiceYourText.tts

import android.speech.tts.Voice
import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceOptionsTest {

    private fun v(name: String, lang: String = "ja", quality: Int = Voice.QUALITY_NORMAL, network: Boolean = false, notInstalled: Boolean = false) =
        VoiceInfo(name, lang, quality, network, notInstalled)

    @Test
    fun 端末内で高品質な声から順に声1声2と名前を付ける() {
        val options = VoiceOptions.build(
            listOf(
                v("ja-net", network = true, quality = Voice.QUALITY_VERY_HIGH),
                v("ja-low"),
                v("ja-high", quality = Voice.QUALITY_HIGH),
                v("en-high", lang = "en", quality = Voice.QUALITY_HIGH),
                v("ja-missing", notInstalled = true),
            ),
            "ja"
        )
        assertEquals(listOf("ja-high", "ja-low", "ja-net", "ja-missing"), options.map { it.name })
        assertEquals(listOf(1, 2, 3, 4), options.map { it.number })
        assertEquals(listOf(true, false, true, false), options.map { it.highQuality })
        assertEquals(listOf(false, false, true, false), options.map { it.requiresNetwork })
        assertEquals(listOf(true, true, true, false), options.map { it.selectable })
    }
}
