package com.entaku.VoiceYourText.kokoro

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.tts.TtsViewModel

@Composable
fun KokoroVoiceSection(viewModel: TtsViewModel) {
    val download by viewModel.kokoroDownload.collectAsState()
    val enabled by viewModel.kokoroEnabled.collectAsState()
    val selected by viewModel.kokoroVoice.collectAsState()
    val previewing by viewModel.kokoroPreview.collectAsState()
    val error by viewModel.kokoroError.collectAsState()
    Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp)) {
        Text(stringResource(R.string.kokoro_title), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.kokoro_note), style = MaterialTheme.typography.bodySmall)
        when {
            download.downloading -> {
                LinearProgressIndicator(progress = { download.progress }, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp))
                Text(stringResource(R.string.kokoro_downloading, (download.progress * 100).toInt()))
                TextButton(onClick = viewModel::cancelKokoroDownload) { Text(stringResource(R.string.common_cancel)) }
            }
            !download.ready -> {
                if (download.failed) Text(stringResource(R.string.kokoro_download_failed), color = MaterialTheme.colorScheme.error)
                TextButton(onClick = viewModel::downloadKokoro) { Text(stringResource(R.string.kokoro_download)) }
            }
            else -> KokoroVoice.entries.forEach { voice ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = enabled && selected == voice, onClick = { viewModel.selectKokoroVoice(voice) })
                    TextButton(onClick = { viewModel.selectKokoroVoice(voice) }, modifier = Modifier.weight(1f)) {
                        Text(voice.displayName)
                    }
                    TextButton(onClick = { if (previewing == voice) viewModel.stopPreview() else viewModel.previewKokoroVoice(voice) }) {
                        Text(stringResource(if (previewing == voice) R.string.kokoro_stop_preview else R.string.voice_preview))
                    }
                }
            }
        }
        if (error) Text(stringResource(R.string.kokoro_failed), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
    }
}
