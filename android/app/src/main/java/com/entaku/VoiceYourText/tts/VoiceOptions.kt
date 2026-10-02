package com.entaku.VoiceYourText.tts

import android.speech.tts.TextToSpeech
import android.speech.tts.Voice

/** 端末の音声1つ分（TextToSpeech.Voice から必要な情報だけ取り出したもの。テストしやすくするため） */
data class VoiceInfo(
    val name: String,
    val language: String,
    val quality: Int,
    val requiresNetwork: Boolean,
    val notInstalled: Boolean,
)

/** 声の選択肢として画面に出す1件 */
data class VoiceOption(
    val name: String,
    val label: String,
    val note: String?,
    val selectable: Boolean,
)

object VoiceOptions {

    /**
     * language の声を、品質が高い順・端末内のものを先に並べ、「声 1」「声 2」…と名前を付ける
     * （Voice.name は "ja-jp-x-jab-local" のように意味が分からないため）。
     * 未ダウンロードの声は選べないが、あることは見せて追加方法を案内する。
     */
    fun build(voices: List<VoiceInfo>, language: String): List<VoiceOption> =
        voices.filter { it.language == language }
            .sortedWith(
                compareBy<VoiceInfo> { it.notInstalled }
                    .thenBy { it.requiresNetwork }
                    .thenByDescending { it.quality }
                    .thenBy { it.name }
            )
            .mapIndexed { i, v ->
                val notes = buildList {
                    if (v.quality >= Voice.QUALITY_HIGH) add("高品質")
                    if (v.requiresNetwork) add("ネット接続が必要")
                    if (v.notInstalled) add("未ダウンロード")
                }
                VoiceOption(
                    name = v.name,
                    label = "声 ${i + 1}",
                    note = notes.joinToString("・").ifEmpty { null },
                    selectable = !v.notInstalled,
                )
            }

    fun from(voice: Voice): VoiceInfo = VoiceInfo(
        name = voice.name,
        language = voice.locale.language,
        quality = voice.quality,
        requiresNetwork = voice.isNetworkConnectionRequired,
        notInstalled = voice.features?.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) == true,
    )
}
