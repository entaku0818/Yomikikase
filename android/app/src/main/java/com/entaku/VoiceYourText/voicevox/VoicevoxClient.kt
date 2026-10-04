package com.entaku.VoiceYourText.voicevox

import android.util.Base64
import com.google.android.gms.tasks.Tasks
import com.google.firebase.appcheck.FirebaseAppCheck
import com.revenuecat.purchases.Purchases
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.time.Instant
import java.time.OffsetDateTime
import java.util.concurrent.TimeUnit

/** 今月の使用量。plan は "free" / "premium" */
data class VoicevoxUsage(
    val plan: String,
    val used: Int,
    val limit: Int,
    val remaining: Int,
    val resetAt: Instant,
) {
    val isPremium: Boolean get() = plan == "premium"
}

sealed class VoicevoxException(message: String, cause: Throwable? = null) : IOException(message, cause) {
    /** 今月の上限に達した。無料ユーザーには課金画面を出す */
    class QuotaExceeded(val usage: VoicevoxUsage) : VoicevoxException("quota exceeded")
    /** App Check トークンか利用者 ID を用意できない（デバッグトークン未登録・課金未設定のビルドなど） */
    class Unavailable(cause: Throwable? = null) : VoicevoxException("voicevox unavailable", cause)
    class Server(val status: Int, val code: String) : VoicevoxException("server error $status $code")
}

/**
 * キャラ音声（VOICEVOX）サーバーのクライアント（iOS VoicevoxClient と同じ API）。
 *
 * サーバーは App Check で本物のアプリからの呼び出しかを確かめ、RevenueCat の App User ID で
 * プレミアム判定と月の文字数を数える（voicevox-server/README.md）。
 */
class VoicevoxClient(
    private val baseUrl: String = BASE_URL,
    private val httpClient: OkHttpClient = defaultHttpClient,
    private val appCheckToken: () -> String = ::firebaseAppCheckToken,
    private val userId: () -> String = ::revenueCatUserId,
) {
    suspend fun quota(): VoicevoxUsage = withContext(Dispatchers.IO) {
        parseUsage(JSONObject(send(authorized("v1/quota").get().build())))
    }

    /** text を speakerId の声で読んだ m4a（AAC）を返す */
    suspend fun synthesize(text: String, speakerId: Int, speedScale: Double): ByteArray = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("text", text)
            .put("speakerId", speakerId)
            .put("speedScale", speedScale)
            .toString()
            .toRequestBody(JSON)
        val response = JSONObject(send(authorized("v1/synthesize").post(body).build()))
        decodeBase64(response.getString("audio"))
    }

    private fun authorized(path: String): Request.Builder {
        val token: String
        val user: String
        try {
            token = appCheckToken()
            user = userId()
        } catch (e: Exception) {
            throw VoicevoxException.Unavailable(e)
        }
        return Request.Builder()
            .url(baseUrl.trimEnd('/') + "/" + path)
            .header("X-Firebase-AppCheck", token)
            .header("X-User-ID", user)
    }

    private fun send(request: Request): String = httpClient.newCall(request).execute().use { response ->
        val body = response.body?.string().orEmpty()
        if (response.code == 429) {
            val usage = runCatching { parseUsage(JSONObject(body).getJSONObject("usage")) }.getOrNull()
            if (usage != null) throw VoicevoxException.QuotaExceeded(usage)
        }
        if (!response.isSuccessful) {
            val code = runCatching { JSONObject(body).getString("error") }.getOrDefault("unknown")
            throw VoicevoxException.Server(response.code, code)
        }
        body
    }

    companion object {
        const val BASE_URL = "https://voicevox-tts-990821915106.asia-northeast1.run.app"
        private val JSON = "application/json".toMediaType()

        private val defaultHttpClient = OkHttpClient.Builder()
            .readTimeout(60, TimeUnit.SECONDS)
            .callTimeout(90, TimeUnit.SECONDS)
            .build()

        fun parseUsage(json: JSONObject) = VoicevoxUsage(
            plan = json.getString("plan"),
            used = json.getInt("used"),
            limit = json.getInt("limit"),
            remaining = json.getInt("remaining"),
            resetAt = OffsetDateTime.parse(json.getString("resetAt")).toInstant(),
        )

        /** テストでは android.util.Base64 が使えないので差し替えられるようにする */
        internal var decodeBase64: (String) -> ByteArray = { Base64.decode(it, Base64.DEFAULT) }

        private fun firebaseAppCheckToken(): String =
            Tasks.await(FirebaseAppCheck.getInstance().getAppCheckToken(false), 20, TimeUnit.SECONDS).token

        private fun revenueCatUserId(): String = Purchases.sharedInstance.appUserID
    }
}
