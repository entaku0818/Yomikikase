package com.entaku.VoiceYourText.tts

import android.speech.tts.Voice
import org.junit.Assert.*
import org.junit.Test

class DeviceVoiceResolverTest {
    private fun voice(name: String, quality: Int = Voice.QUALITY_NORMAL, network: Boolean = false,
                      missing: Boolean = false, language: String = "ja", locale: String = "ja-JP") =
        VoiceInfo(name, language, quality, network, missing, locale)

    @Test fun automaticallyChoosesBestInstalledOfflineVoice() {
        val voices = listOf(voice("base"), voice("better", Voice.QUALITY_HIGH),
            voice("network", Voice.QUALITY_VERY_HIGH, network = true),
            voice("missing", Voice.QUALITY_VERY_HIGH, missing = true))
        assertEquals("better", VoiceOptions.resolve(voices, "ja", null, "base"))
    }
    @Test fun savedLowQualityAndNetworkChoicesAreRespected() {
        val voices = listOf(voice("base"), voice("better", Voice.QUALITY_HIGH), voice("network", network = true))
        assertEquals("base", VoiceOptions.resolve(voices, "ja", "base", "better"))
        assertEquals("network", VoiceOptions.resolve(voices, "ja", "network", "better"))
    }
    @Test fun missingSavedVoiceUsesAutomaticSelection() {
        val voices = listOf(voice("base"), voice("better", Voice.QUALITY_HIGH), voice("missing", missing = true))
        assertEquals("better", VoiceOptions.resolve(voices, "ja", "missing", "base"))
        assertEquals("better", VoiceOptions.resolve(voices, "ja", "removed", "base"))
    }
    @Test fun wrongLanguageSavedVoiceIsIgnored() {
        val voices = listOf(voice("ja"), voice("en", language = "en", locale = "en-US"))
        assertEquals("ja", VoiceOptions.resolve(voices, "ja", "en", "ja"))
    }
    @Test fun equalQualityKeepsEngineDefault() {
        val voices = listOf(voice("a"), voice("z"))
        assertEquals("z", VoiceOptions.resolve(voices, "ja", null, "z"))
    }
    @Test fun automaticSelectionPreservesDefaultAccent() {
        val voices = listOf(voice("us", language = "en", locale = "en-US"),
            voice("us-high", Voice.QUALITY_HIGH, language = "en", locale = "en-US"),
            voice("gb-high", Voice.QUALITY_VERY_HIGH, language = "en", locale = "en-GB"))
        assertEquals("us-high", VoiceOptions.resolve(voices, "en", null, "us"))
    }
    @Test fun noInstalledOfflineVoiceKeepsDefault() {
        val voices = listOf(voice("network", network = true), voice("missing", missing = true))
        assertEquals("network", VoiceOptions.resolve(voices, "ja", null, "network"))
    }
    @Test fun noDefaultUsesStableOfflineChoice() {
        val voices = listOf(voice("z"), voice("a"))
        assertEquals("a", VoiceOptions.resolve(voices, "ja", null, null))
        assertEquals("a", VoiceOptions.resolve(voices.reversed(), "ja", null, null))
    }
    @Test fun emptyOrWrongLanguageInventoryHasNoSelection() {
        assertNull(VoiceOptions.resolve(emptyList(), "ja", null, null))
        assertNull(VoiceOptions.resolve(listOf(voice("en", language = "en")), "ja", null, "en"))
    }
}
