package com.entaku.VoiceYourText.feedback

import android.os.Build
import com.entaku.VoiceYourText.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

/**
 * フィードバックを Cloud Functions `submitFeedback` に送る（iOS `FeedbackClient` と同じ窓口・同じ項目）。
 * サーバーが Firestore の `feedback` コレクションに保存する。
 * iOS と区別できるよう osVersion は "Android 13" の形で送る。
 *
 * App Check トークンはまだ付けていない（サーバーは監視モードなので受理される）。
 * サーバー側で App Check を必須にする前に Android にも Play Integrity を入れること（#151）。
 */
class FeedbackClient(
    private val endpoint: String = ENDPOINT,
    private val httpClient: OkHttpClient = OkHttpClient(),
    private val appVersion: String = BuildConfig.VERSION_NAME,
    private val osVersion: String = "Android ${Build.VERSION.RELEASE}",
    private val deviceModel: String = "${Build.MANUFACTURER} ${Build.MODEL}",
) {
    suspend fun submit(message: String) = withContext(Dispatchers.IO) {
        val body = payload(message, appVersion, osVersion, deviceModel)
            .toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url(endpoint).post(body).build()
        httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw IOException("submitFeedback failed: HTTP ${response.code}")
        }
    }

    companion object {
        /** サーバーが受け取る JSON（message / appVersion / osVersion / deviceModel） */
        fun payload(message: String, appVersion: String, osVersion: String, deviceModel: String): String =
            listOf(
                "message" to message,
                "appVersion" to appVersion,
                "osVersion" to osVersion,
                "deviceModel" to deviceModel,
            ).joinToString(",", "{", "}") { (key, value) -> "\"$key\":${jsonString(value)}" }

        private fun jsonString(value: String): String = buildString {
            append('"')
            value.forEach { c ->
                when {
                    c == '"' -> append("\\\"")
                    c == '\\' -> append("\\\\")
                    c == '\n' -> append("\\n")
                    c == '\r' -> append("\\r")
                    c == '\t' -> append("\\t")
                    c < ' ' -> append("\\u%04x".format(c.code))
                    else -> append(c)
                }
            }
            append('"')
        }

        const val ENDPOINT = "https://asia-northeast1-voiceyourtext.cloudfunctions.net/submitFeedback"

        /** サーバー（functions/index.js の MESSAGE_MAX_LENGTH）と同じ上限 */
        const val MAX_LENGTH = 2000
    }
}
