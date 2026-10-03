package com.entaku.VoiceYourText.tts

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.entaku.VoiceYourText.R

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

/** 声の選択肢として画面に出す1件。number は「声 1」「声 2」の番号 */
data class VoiceOption(
    val name: String,
    val number: Int,
    val highQuality: Boolean,
    val requiresNetwork: Boolean,
    val notInstalled: Boolean,
) {
    val selectable: Boolean get() = !notInstalled
}

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
                VoiceOption(
                    name = v.name,
                    number = i + 1,
                    highQuality = v.quality >= Voice.QUALITY_HIGH,
                    requiresNetwork = v.requiresNetwork,
                    notInstalled = v.notInstalled,
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

/** 「声 1」「声 2」… */
@Composable
fun voiceLabel(option: VoiceOption): String = stringResource(R.string.voice_label, option.number)

/** 高品質・ネット接続が必要・未ダウンロード を「・」でつなげた補足（無ければ null） */
@Composable
fun voiceNote(option: VoiceOption): String? = buildList {
    if (option.highQuality) add(stringResource(R.string.voice_high_quality))
    if (option.requiresNetwork) add(stringResource(R.string.voice_requires_network))
    if (option.notInstalled) add(stringResource(R.string.voice_not_installed))
}.joinToString(" · ").ifEmpty { null }
