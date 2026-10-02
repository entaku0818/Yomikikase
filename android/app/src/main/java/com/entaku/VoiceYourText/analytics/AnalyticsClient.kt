package com.entaku.VoiceYourText.analytics

import android.content.Context
import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics

/**
 * GA4 へイベントを送る窓口。イベント名・パラメータ名は iOS 版と揃える
 * （同じ GA4 プロパティで iOS と Android を並べて見るため）。
 */
interface AnalyticsClient {
    fun logEvent(name: String, params: Map<String, Any?> = emptyMap())

    companion object {
        @Volatile
        private var instance: AnalyticsClient? = null

        fun get(context: Context): AnalyticsClient =
            instance ?: synchronized(this) {
                instance ?: FirebaseAnalyticsClient(context.applicationContext).also { instance = it }
            }
    }
}

class FirebaseAnalyticsClient(context: Context) : AnalyticsClient {
    private val firebase = FirebaseAnalytics.getInstance(context)

    override fun logEvent(name: String, params: Map<String, Any?>) {
        firebase.logEvent(name, params.toBundle())
    }
}

/** ユニットテスト用。送ったイベントを記録するだけ。 */
class RecordingAnalyticsClient : AnalyticsClient {
    val events = mutableListOf<Pair<String, Map<String, Any?>>>()

    override fun logEvent(name: String, params: Map<String, Any?>) {
        events += name to params
    }
}

internal fun Map<String, Any?>.toBundle(): Bundle = Bundle().also { bundle ->
    forEach { (key, value) ->
        when (value) {
            null -> Unit
            is String -> bundle.putString(key, value)
            is Int -> bundle.putLong(key, value.toLong())
            is Long -> bundle.putLong(key, value)
            is Float -> bundle.putDouble(key, value.toDouble())
            is Double -> bundle.putDouble(key, value)
            is Boolean -> bundle.putString(key, value.toString())
            else -> bundle.putString(key, value.toString())
        }
    }
}
