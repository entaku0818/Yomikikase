package com.entaku.VoiceYourText.tts

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.entaku.VoiceYourText.R

@Composable
fun MyVoiceSection(viewModel: TtsViewModel, onApplied: () -> Unit) {
    val preset by viewModel.voicePreset.collectAsState()
    val language by viewModel.selectedLanguage.collectAsState()
    val rate by viewModel.speechRate.collectAsState()
    val pitch by viewModel.pitch.collectAsState()
    val options by viewModel.voiceOptions.collectAsState()
    val ready by viewModel.isInitialized.collectAsState()
    val voicevox by viewModel.voicevoxEnabled.collectAsState()
    val catalog by viewModel.voicevoxCatalog.collectAsState()
    val kokoro by viewModel.kokoroEnabled.collectAsState()
    val model by viewModel.kokoroDownload.collectAsState()
    Column(Modifier.padding(horizontal = 24.dp, vertical = 8.dp)) {
        Text(stringResource(R.string.my_voice_title, language.displayName), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.my_voice_hint), style = MaterialTheme.typography.bodySmall)
        Text(stringResource(R.string.settings_speed) + " ×%.1f".format(rate))
        Slider(value = rate, onValueChange = viewModel::setSpeechRate, valueRange = 0.5f..2f)
        // VOICEVOX currently supports speed only; do not promise a pitch change for that engine.
        if (language.code != "ja" || (!voicevox && !kokoro)) {
            Text(stringResource(R.string.settings_pitch) + " ×%.1f".format(pitch))
            Slider(value = pitch, onValueChange = viewModel::setPitch, valueRange = 0.5f..2f)
        }
        TextButton(onClick = viewModel::saveVoicePreset, enabled = ready || (kokoro && model.ready)) {
            Text(stringResource(if (preset == null) R.string.my_voice_save else R.string.my_voice_update))
        }
        preset?.let { saved ->
            val label = if (saved.kokoroVoice != null) com.entaku.VoiceYourText.kokoro.KokoroVoice.fromId(saved.kokoroVoice)?.displayName ?: stringResource(R.string.my_voice_unavailable)
                else if (saved.speakerId != null) catalog?.voice(saved.speakerId)?.character ?: stringResource(R.string.my_voice_unavailable)
                else options.firstOrNull { it.name == saved.voiceName }?.let { voiceLabel(it) }
                    ?: stringResource(if (saved.voiceName == null) R.string.speech_voice_default else R.string.my_voice_unavailable)
            Text(label + " · ×%.1f".format(saved.rate), style = MaterialTheme.typography.bodySmall)
            val available = viewModel.canApplyPreset(saved)
            if (!available) Text(stringResource(R.string.my_voice_unavailable), style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { viewModel.applyVoicePreset(); onApplied() }, enabled = (ready || (kokoro && model.ready)) && available) {
                Text(stringResource(R.string.my_voice_apply))
            }
            TextButton(onClick = viewModel::deleteVoicePreset) { Text(stringResource(R.string.my_voice_delete)) }
        }
    }
}
