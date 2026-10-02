package com.entaku.VoiceYourText.analytics

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Test
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito.`when`
import org.mockito.Mockito.mock

class SpeechCompletionTrackerTest {

    /** putInt した値を getInt で返すだけの SharedPreferences モック */
    private fun inMemoryPrefs(): SharedPreferences {
        val store = mutableMapOf<String, Int>()
        val editor = mock(SharedPreferences.Editor::class.java)
        `when`(editor.putInt(anyString(), anyInt())).thenAnswer {
            store[it.getArgument(0)] = it.getArgument(1)
            editor
        }
        val prefs = mock(SharedPreferences::class.java)
        `when`(prefs.edit()).thenReturn(editor)
        `when`(prefs.getInt(anyString(), anyInt())).thenAnswer {
            store[it.getArgument(0)] ?: it.getArgument(1)
        }
        return prefs
    }

    @Test
    fun 完了のたびに回数を増やしてiOSと同じイベントを送る() {
        val analytics = RecordingAnalyticsClient()
        val tracker = SpeechCompletionTracker(inMemoryPrefs(), analytics)

        assertEquals(1, tracker.onSpeechCompleted("text"))
        assertEquals(2, tracker.onSpeechCompleted("pdf"))

        assertEquals(
            listOf(
                "speech_completed" to mapOf("count" to 1, "source" to "text"),
                "speech_completed" to mapOf("count" to 2, "source" to "pdf"),
            ),
            analytics.events
        )
    }
}
