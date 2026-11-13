package com.entaku.VoiceYourText.tts

import android.content.SharedPreferences
import androidx.core.content.edit
import java.security.MessageDigest
import java.text.BreakIterator

/** Files are deduplicated by their full content, so a stable content hash identifies their position.
 * Only the hash and UTF-16 offset are stored; changing the text starts a fresh playback.
 */
class PlaybackResumeStore(private val prefs: SharedPreferences) {
    private var cachedText: String? = null
    private var cachedKey: String = ""

    private fun key(text: String): String {
        if (cachedText != text) {
            cachedKey = MessageDigest.getInstance("SHA-256")
                .digest(text.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
            cachedText = text
        }
        return cachedKey
    }

    fun position(text: String): Int = safeOffset(text, prefs.getInt(key(text), 0))

    fun save(text: String, offset: Int) {
        val safe = safeOffset(text, offset)
        prefs.edit {
            if (safe > 0) putInt(key(text), safe) else remove(key(text))
        }
    }

    fun clear(text: String) { prefs.edit { remove(key(text)) } }

    companion object {
        const val PREFS_NAME = "playback_resume"

        internal fun safeOffset(text: String, offset: Int): Int {
            if (offset <= 0 || offset >= text.length) return 0
            val boundaries = BreakIterator.getCharacterInstance().apply { setText(text) }
            return if (boundaries.isBoundary(offset)) offset else boundaries.preceding(offset)
        }
    }
}
