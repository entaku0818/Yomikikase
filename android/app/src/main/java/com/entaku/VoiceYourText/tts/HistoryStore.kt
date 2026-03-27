package com.entaku.VoiceYourText.tts

import android.content.Context
import androidx.core.content.edit

class HistoryStore(context: Context) {
    private val prefs = context.getSharedPreferences("speech_history", Context.MODE_PRIVATE)

    fun save(text: String) {
        val history = getAll().toMutableList()
        history.remove(text) // remove duplicate
        history.add(0, text)
        val trimmed = history.take(MAX_ITEMS)
        prefs.edit {
            putStringSet(KEY_HISTORY, trimmed.toSet())
            putString(KEY_ORDER, trimmed.joinToString(SEPARATOR) { it.replace(SEPARATOR, " ") })
        }
    }

    fun getAll(): List<String> {
        val order = prefs.getString(KEY_ORDER, null) ?: return emptyList()
        return order.split(SEPARATOR).filter { it.isNotBlank() }
    }

    fun delete(text: String) {
        val history = getAll().toMutableList()
        history.remove(text)
        prefs.edit {
            putStringSet(KEY_HISTORY, history.toSet())
            putString(KEY_ORDER, history.joinToString(SEPARATOR) { it.replace(SEPARATOR, " ") })
        }
    }

    companion object {
        private const val KEY_HISTORY = "history"
        private const val KEY_ORDER = "history_order"
        private const val SEPARATOR = "\u0000"
        private const val MAX_ITEMS = 50
    }
}
