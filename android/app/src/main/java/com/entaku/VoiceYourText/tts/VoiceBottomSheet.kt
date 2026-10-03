package com.entaku.VoiceYourText.tts

import com.entaku.VoiceYourText.R
import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/** 声の選択シート。未ダウンロードの声は選べないので、端末の設定で追加する導線を出す */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceBottomSheet(
    options: List<VoiceOption>,
    selectedName: String?,
    onSelect: (String?) -> Unit,
    onAddVoices: () -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = stringResource(R.string.voice_select),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp)
            )
            HorizontalDivider()
            VoiceRow(label = stringResource(R.string.speech_voice_default), note = stringResource(R.string.voice_default_note), selected = selectedName == null, enabled = true) {
                onSelect(null)
                onDismiss()
            }
            options.forEach { option ->
                VoiceRow(
                    label = voiceLabel(option),
                    note = voiceNote(option),
                    selected = option.name == selectedName,
                    enabled = option.selectable
                ) {
                    onSelect(option.name)
                    onDismiss()
                }
            }
            if (options.any { !it.selectable } || options.isEmpty()) {
                TextButton(onClick = onAddVoices, modifier = Modifier.padding(horizontal = 12.dp)) {
                    Text(stringResource(R.string.voice_add))
                }
            }
        }
    }
}

@Composable
private fun VoiceRow(label: String, note: String?, selected: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RadioButton(selected = selected, onClick = if (enabled) onClick else null, enabled = enabled)
        Column(modifier = Modifier.padding(start = 8.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (note != null) {
                Text(text = note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
