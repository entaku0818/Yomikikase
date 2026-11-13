package com.entaku.VoiceYourText.voicevox

import android.content.Context
import androidx.core.content.edit
import org.json.JSONObject
import java.net.URI

/** キャラ情報はサーバーから取得し、固定の名前・ID一覧をアプリに持たない。 */
data class VoicevoxVoice(val speakerId: Int, val character: String, val style: String, val credit: String, val termsUrl: String)

data class VoicevoxCatalog(
    val schemaVersion: Int,
    val revision: String,
    val defaultSpeakerId: Int?,
    val termsUrl: String,
    val voices: List<VoicevoxVoice>,
    val credits: List<VoicevoxVoice>,
) {
    fun voice(speakerId: Int): VoicevoxVoice? = voices.firstOrNull { it.speakerId == speakerId }
    fun selection(savedId: Int): Int? = voice(savedId)?.speakerId ?: defaultSpeakerId

    fun validated(): VoicevoxCatalog {
        require(schemaVersion == 1 && revision.isNotBlank() && isHttps(termsUrl))
        require(voices.map { it.speakerId }.distinct().size == voices.size)
        require(credits.map { it.speakerId }.distinct().size == credits.size)
        require((voices + credits).all { it.speakerId >= 0 && it.character.isNotBlank() && it.style.isNotBlank() && it.credit.isNotBlank() && isHttps(it.termsUrl) })
        require(voices.all { voice -> credits.any { it.speakerId == voice.speakerId } })
        require(if (voices.isEmpty()) defaultSpeakerId == null else defaultSpeakerId != null && voice(defaultSpeakerId) != null)
        return this
    }

    companion object {
        const val UNSELECTED_SPEAKER_ID = -1
        fun isAvailable(languageCode: String): Boolean = languageCode.startsWith("ja")
        fun previewText(voice: VoicevoxVoice): String = "こんにちは、${voice.character}です。この声で読み上げます。"
        private fun isHttps(raw: String): Boolean = runCatching {
            val uri = URI(raw)
            uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null
        }.getOrDefault(false)
    }
}

/** クレジットは通信できないときも最後に検証済みの一覧を表示できる。 */
class VoicevoxCatalogCache(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("voicevox_catalog_v1", Context.MODE_PRIVATE)
    fun load(): VoicevoxCatalog? = runCatching {
        prefs.getString("json", null)?.let { VoicevoxClient.parseCatalog(JSONObject(it)) }
    }.getOrNull()
    fun store(json: String) {
        VoicevoxClient.parseCatalog(JSONObject(json))
        prefs.edit { putString("json", json) }
    }
}

/** 選んだ声はIDだけを保存する。新しいサーバーIDも既存の値も固定一覧で丸めない。 */
class VoicevoxSettings(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("voicevox", Context.MODE_PRIVATE)
    var isEnabled: Boolean
        get() = prefs.getBoolean("enabled", false)
        set(value) = prefs.edit { putBoolean("enabled", value) }
    var speakerId: Int
        get() = prefs.getInt("speaker_id", VoicevoxCatalog.UNSELECTED_SPEAKER_ID)
        set(value) = prefs.edit { putInt("speaker_id", value) }
}
