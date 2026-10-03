package com.entaku.VoiceYourText.dictionary

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

/** ユーザー辞書の1件（iOS `UserDictionaryEntry` と同じ項目）。読み上げ前に word を reading に置き換える */
data class UserDictionaryEntry(
    val id: String = UUID.randomUUID().toString(),
    val word: String,
    val reading: String,
    val createdAt: Long = System.currentTimeMillis(),
)

/**
 * ユーザー辞書の保存先（iOS と同じく全言語共通の1つの一覧）。
 * 1行1件のタブ区切りで SharedPreferences に保存する（タブ・改行・\ はエスケープ）。
 */
class UserDictionaryStore(private val prefs: SharedPreferences) {

    private val _entries = MutableStateFlow(decode(prefs.getString(KEY, null).orEmpty()))
    val entries: StateFlow<List<UserDictionaryEntry>> = _entries.asStateFlow()

    /** 読み上げ前の整形（SpeechTextPreprocessor）に渡す (単語, 読み) */
    val readings: List<Pair<String, String>> get() = _entries.value.map { it.word to it.reading }

    fun add(word: String, reading: String) {
        val w = word.trim()
        val r = reading.trim()
        if (w.isEmpty() || r.isEmpty()) return
        // 同じ単語はあとから登録した読み方で上書きする
        save(_entries.value.filterNot { it.word == w } + UserDictionaryEntry(word = w, reading = r))
    }

    fun delete(id: String) = save(_entries.value.filterNot { it.id == id })

    private fun save(entries: List<UserDictionaryEntry>) {
        _entries.value = entries
        prefs.edit { putString(KEY, encode(entries)) }
    }

    companion object {
        private const val PREFS_NAME = "user_dictionary"
        private const val KEY = "entries"

        @Volatile
        private var instance: UserDictionaryStore? = null

        fun get(context: Context): UserDictionaryStore = instance ?: synchronized(this) {
            instance ?: UserDictionaryStore(
                context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ).also { instance = it }
        }

        fun encode(entries: List<UserDictionaryEntry>): String =
            entries.joinToString("\n") { e -> listOf(e.id, e.word, e.reading, e.createdAt.toString()).joinToString("\t") { escape(it) } }

        fun decode(text: String): List<UserDictionaryEntry> =
            text.split("\n").filter { it.isNotEmpty() }.mapNotNull { line ->
                val f = line.split("\t").map(::unescape)
                if (f.size < 4) null else UserDictionaryEntry(f[0], f[1], f[2], f[3].toLongOrNull() ?: 0L)
            }

        private fun escape(s: String) = s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")

        private fun unescape(s: String): String {
            val out = StringBuilder()
            var i = 0
            while (i < s.length) {
                val c = s[i]
                if (c == '\\' && i + 1 < s.length) {
                    out.append(when (s[i + 1]) { 't' -> '\t'; 'n' -> '\n'; else -> s[i + 1] })
                    i += 2
                } else {
                    out.append(c); i++
                }
            }
            return out.toString()
        }
    }
}
