package com.entaku.VoiceYourText.tts

import android.content.SharedPreferences
import androidx.core.content.edit
import org.json.JSONObject

/** One saved voice configuration per reading language. */
data class VoicePreset(
    val voiceName: String?,
    val speakerId: Int?,
    val rate: Float,
    val pitch: Float,
    val kokoroVoice: String? = null,
) {
    fun encode(): String = JSONObject().apply {
        put("voice", voiceName ?: JSONObject.NULL)
        put("speaker", speakerId ?: JSONObject.NULL)
        put("kokoro", kokoroVoice ?: JSONObject.NULL)
        put("rate", rate.toDouble())
        put("pitch", pitch.toDouble())
    }.toString()

    companion object {
        fun decode(value: String?): VoicePreset? = runCatching {
            val json = JSONObject(value ?: return null)
            val rate = json.getDouble("rate").toFloat()
            val pitch = json.getDouble("pitch").toFloat()
            require(rate in 0.5f..2f && pitch in 0.5f..2f)
            VoicePreset(
                if (json.isNull("voice")) null else json.getString("voice"),
                if (json.isNull("speaker")) null else json.getInt("speaker"), rate, pitch,
                if (json.isNull("kokoro")) null else json.getString("kokoro"),
            )
        }.getOrNull()
    }
}

class VoicePresetStore(private val prefs: SharedPreferences) {
    fun load(language: String): VoicePreset? = VoicePreset.decode(prefs.getString(language, null))
    fun save(language: String, preset: VoicePreset) { prefs.edit { putString(language, preset.encode()) } }
    fun delete(language: String) { prefs.edit { remove(language) } }
}
