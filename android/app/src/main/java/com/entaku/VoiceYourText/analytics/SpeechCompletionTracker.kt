package com.entaku.VoiceYourText.analytics

import android.content.SharedPreferences
import androidx.core.content.edit

/**
 * 読み上げを最後まで聴いた回数を数え、iOS と同じ `speech_completed` イベントを送る。
 * 途中で止めた場合（stop）は数えない。
 */
class SpeechCompletionTracker(
    private val prefs: SharedPreferences,
    private val analytics: AnalyticsClient,
) {
    fun onSpeechCompleted(source: String): Int {
        val count = prefs.getInt(KEY_COUNT, 0) + 1
        prefs.edit { putInt(KEY_COUNT, count) }
        analytics.logEvent("speech_completed", mapOf("count" to count, "source" to source))
        return count
    }

    companion object {
        const val PREFS_NAME = "speech_stats"
        const val KEY_COUNT = "speech_completed_count"
    }
}
