package com.entaku.VoiceYourText.voicevox

import android.content.Context
import androidx.core.content.edit

/** キャラ音声（VOICEVOX）の声。credit はアプリ内に表記する文言（各キャラの規約どおり） */
data class VoicevoxVoice(
    val speakerId: Int,
    val character: String,
    val style: String,
    val credit: String,
    val termsUrl: String,
)

/**
 * アプリで選べるキャラ音声。iOS（VoicevoxCatalog.swift）とサーバーの許可リスト
 * （voicevox-server/internal/voices）と同じ内容にする。
 *
 * 有料アプリで申請なしに使えることを各キャラの利用規約で確認した声だけを載せている（2026-09-27）。
 * 声を足すときは、キャラの規約とクレジット書式を確認し、サーバー側の許可リストにも追加すること。
 */
object VoicevoxCatalog {
    val voices = listOf(
        VoicevoxVoice(14, "冥鳴ひまり", "ノーマル", "VOICEVOX:冥鳴ひまり", "https://meimeihimari.wixsite.com/himari/terms-of-use"),
        VoicevoxVoice(3, "ずんだもん", "ノーマル", "VOICEVOX:ずんだもん", "https://zunko.jp/con_ongen_kiyaku.html"),
        VoicevoxVoice(2, "四国めたん", "ノーマル", "VOICEVOX:四国めたん", "https://zunko.jp/con_ongen_kiyaku.html"),
        VoicevoxVoice(11, "玄野武宏", "ノーマル", "VOICEVOX:玄野武宏(CV:ガロ)", "https://www.virvoxproject.com/voicevoxの利用規約"),
        VoicevoxVoice(12, "白上虎太郎", "ふつう", "VOICEVOX:白上虎太郎(CV:可愛ユウ)", "https://www.virvoxproject.com/voicevoxの利用規約"),
        VoicevoxVoice(9, "波音リツ", "ノーマル", "VOICEVOX:波音リツ", "https://www.canon-voice.com/terms"),
    )

    const val DEFAULT_SPEAKER_ID = 14
    const val VOICEVOX_TERMS_URL = "https://voicevox.hiroshiba.jp/term/"

    fun voice(speakerId: Int): VoicevoxVoice = voices.firstOrNull { it.speakerId == speakerId } ?: voices[0]

    /** キャラ音声は日本語の文章だけに使う */
    fun isAvailable(languageCode: String): Boolean = languageCode.startsWith("ja")

    fun previewText(voice: VoicevoxVoice): String = "こんにちは、${voice.character}です。この声で読み上げます。"
}

/** キャラ音声のオン・オフと選んだ声（端末に保存） */
class VoicevoxSettings(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var isEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) = prefs.edit { putBoolean(KEY_ENABLED, value) }

    var speakerId: Int
        // 許可リストから外れた声が保存されていたら既定に戻す
        get() = prefs.getInt(KEY_SPEAKER, VoicevoxCatalog.DEFAULT_SPEAKER_ID)
            .takeIf { id -> VoicevoxCatalog.voices.any { it.speakerId == id } }
            ?: VoicevoxCatalog.DEFAULT_SPEAKER_ID
        set(value) = prefs.edit { putInt(KEY_SPEAKER, value) }

    private companion object {
        const val PREFS = "voicevox"
        const val KEY_ENABLED = "enabled"
        const val KEY_SPEAKER = "speaker_id"
    }
}
