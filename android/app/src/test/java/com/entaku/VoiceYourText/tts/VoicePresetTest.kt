package com.entaku.VoiceYourText.tts

import android.content.SharedPreferences
import org.junit.Assert.*
import org.junit.Test
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.isNull
import org.mockito.Mockito.`when`
import org.mockito.Mockito.mock

class VoicePresetTest {
    @Test fun defaultDeviceAndCharacterVoicesRoundTrip() {
        listOf(
            VoicePreset(null, null, 1f, 1f),
            VoicePreset("ja voice / 日本語", null, 0.5f, 2f),
            VoicePreset("device", 14, 1.2f, 0.8f),
        ).forEach { assertEquals(it, VoicePreset.decode(it.encode())) }
    }

    @Test fun corruptAndOutOfRangeSettingsAreIgnored() {
        assertNull(VoicePreset.decode(null))
        assertNull(VoicePreset.decode("garbage"))
        assertNull(VoicePreset.decode("{}"))
        assertNull(VoicePreset.decode(VoicePreset(null, null, 0f, 1f).encode()))
        assertNull(VoicePreset.decode(VoicePreset(null, null, 1f, 3f).encode()))
    }

    @Test fun presetsSurviveReopeningAndCanBeReplacedAndDeletedPerLanguage() {
        val values = mutableMapOf<String, String>()
        val prefs = mock(SharedPreferences::class.java)
        val editor = mock(SharedPreferences.Editor::class.java)
        `when`(prefs.edit()).thenReturn(editor)
        `when`(prefs.getString(anyString(), isNull())).thenAnswer { values[it.getArgument<String>(0)] }
        `when`(editor.putString(anyString(), anyString())).thenAnswer {
            values[it.getArgument(0)] = it.getArgument(1); editor
        }
        `when`(editor.remove(anyString())).thenAnswer { values.remove(it.getArgument<String>(0)); editor }
        val japanese = VoicePreset(null, 14, 1.2f, 1f)
        val english = VoicePreset("en", null, 0.8f, 1.3f)
        VoicePresetStore(prefs).apply { save("ja", japanese); save("en", english) }
        val reopened = VoicePresetStore(prefs)
        assertEquals(japanese, reopened.load("ja"))
        assertEquals(english, reopened.load("en"))
        reopened.save("ja", japanese.copy(rate = 1.5f))
        assertEquals(1.5f, reopened.load("ja")!!.rate, 0.001f)
        reopened.delete("ja")
        assertNull(reopened.load("ja"))
        assertEquals(english, reopened.load("en"))
    }
}
