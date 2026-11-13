package com.entaku.VoiceYourText.tts

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Test
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito.`when`
import org.mockito.Mockito.mock

class PlaybackResumeStoreTest {
    private fun prefs(): SharedPreferences {
        val values = mutableMapOf<String, Int>()
        val prefs = mock(SharedPreferences::class.java)
        val editor = mock(SharedPreferences.Editor::class.java)
        `when`(prefs.edit()).thenReturn(editor)
        `when`(prefs.getInt(anyString(), anyInt())).thenAnswer {
            values[it.getArgument<String>(0)] ?: it.getArgument<Int>(1)
        }
        `when`(editor.putInt(anyString(), anyInt())).thenAnswer {
            values[it.getArgument(0)] = it.getArgument(1)
            editor
        }
        `when`(editor.remove(anyString())).thenAnswer {
            values.remove(it.getArgument<String>(0))
            editor
        }
        return prefs
    }

    @Test fun restoresAcrossInstancesAndKeepsFilesIndependent() {
        val prefs = prefs()
        val store = PlaybackResumeStore(prefs)
        store.save("First sentence. Second sentence.", 16)
        store.save("Other file content.", 6)
        val reopened = PlaybackResumeStore(prefs)
        assertEquals(16, reopened.position("First sentence. Second sentence."))
        assertEquals(6, reopened.position("Other file content."))
        assertEquals(0, reopened.position("Edited sentence. Second sentence."))
    }

    @Test fun completionAndInvalidOffsetsStartFromBeginning() {
        val store = PlaybackResumeStore(prefs())
        val text = "abcdef"
        store.save(text, 3)
        store.clear(text)
        assertEquals(0, store.position(text))
        for (offset in listOf(-1, 0, text.length, 100)) {
            store.save(text, 3)
            store.save(text, offset)
            assertEquals(0, store.position(text))
        }
    }

    @Test fun neverStartsInsideAnEmojiOrCombiningCharacter() {
        val store = PlaybackResumeStore(prefs())
        store.save("a😀bc", 2)
        assertEquals(1, store.position("a😀bc"))
        store.save("ae\u0301bc", 2)
        assertEquals(1, store.position("ae\u0301bc"))
    }
}
