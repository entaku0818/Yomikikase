package com.entaku.VoiceYourText

import android.content.Context
import android.content.SharedPreferences
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.any
import org.mockito.Mockito.anyInt
import org.mockito.Mockito.anyString
import org.mockito.Mockito.`when`
import org.mockito.junit.MockitoJUnitRunner
import com.entaku.VoiceYourText.tts.HistoryStore
import org.junit.Assert.*

@RunWith(MockitoJUnitRunner::class)
class HistoryStoreTest {

    @Mock
    private lateinit var mockContext: Context

    @Mock
    private lateinit var mockPrefs: SharedPreferences

    @Mock
    private lateinit var mockEditor: SharedPreferences.Editor

    @Before
    fun setup() {
        `when`(mockContext.getSharedPreferences(anyString(), anyInt())).thenReturn(mockPrefs)
        `when`(mockPrefs.edit()).thenReturn(mockEditor)
        `when`(mockEditor.putString(anyString(), any())).thenReturn(mockEditor)
    }

    @Test
    fun `getAll returns empty list when no history saved`() {
        `when`(mockPrefs.getString(anyString(), any())).thenReturn(null)
        val store = HistoryStore(mockContext)
        val result = store.getAll()
        assertTrue("Should return empty list", result.isEmpty())
    }
}
