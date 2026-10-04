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
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import com.entaku.VoiceYourText.ui.localizedMonthDayFormat
import com.entaku.VoiceYourText.voicevox.VoicevoxCatalog
import com.entaku.VoiceYourText.voicevox.VoicevoxUsage
import java.text.NumberFormat
import java.util.Date

/** 声の一覧に出すキャラ音声（VOICEVOX）の状態。日本語の文章のときだけ渡す */
data class VoicevoxPicker(
    val enabled: Boolean,
    val speakerId: Int,
    val previewingSpeakerId: Int?,
    val usage: VoicevoxUsage?,
    val usageUnavailable: Boolean,
    val onSelectVoice: (Int) -> Unit,
    val onUpgrade: () -> Unit,
)

/** 声の選択シート。未ダウンロードの声は選べないので、端末の設定で追加する導線を出す */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceBottomSheet(
    options: List<VoiceOption>,
    selectedName: String?,
    onSelect: (String?) -> Unit,
    onAddVoices: () -> Unit,
    onDismiss: () -> Unit,
    voicevox: VoicevoxPicker? = null,
) {
    // キャラ音声を使っているときは端末の声にチェックを付けない
    val deviceSelected = voicevox?.enabled != true
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
            if (voicevox != null) {
                VoicevoxSection(voicevox)
                HorizontalDivider()
                SectionHeader(stringResource(R.string.voicevox_device_voices))
            }
            VoiceRow(label = stringResource(R.string.speech_voice_default), note = stringResource(R.string.voice_default_note), selected = deviceSelected && selectedName == null, enabled = true) {
                onSelect(null)
                onDismiss()
            }
            options.forEach { option ->
                VoiceRow(
                    label = voiceLabel(option),
                    note = voiceNote(option),
                    selected = deviceSelected && option.name == selectedName,
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
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 4.dp)
    )
}

@Composable
private fun VoicevoxSection(picker: VoicevoxPicker) {
    SectionHeader(stringResource(R.string.voicevox_section_title))
    VoicevoxCatalog.voices.forEach { voice ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                VoiceRow(
                    label = voice.character,
                    note = voice.style,
                    selected = picker.enabled && picker.speakerId == voice.speakerId,
                    enabled = true,
                ) { picker.onSelectVoice(voice.speakerId) }
            }
            if (picker.previewingSpeakerId == voice.speakerId) {
                CircularProgressIndicator(modifier = Modifier.padding(end = 24.dp).size(20.dp), strokeWidth = 2.dp)
            }
        }
    }
    Column(
        modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp)
    ) {
        val usage = picker.usage
        if (picker.enabled && usage != null) {
            val number = NumberFormat.getIntegerInstance()
            Text(
                text = stringResource(R.string.voicevox_usage, number.format(usage.remaining), number.format(usage.limit)),
                style = MaterialTheme.typography.bodyMedium
            )
            LinearProgressIndicator(
                progress = { usage.used.toFloat() / usage.limit.coerceAtLeast(1) },
                modifier = Modifier.fillMaxWidth()
            )
            Text(
                text = stringResource(R.string.voicevox_resets_on, localizedMonthDayFormat().format(Date.from(usage.resetAt))),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else if (picker.enabled && picker.usageUnavailable) {
            Text(
                text = stringResource(R.string.voicevox_usage_unavailable),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            text = stringResource(R.string.voicevox_picker_note),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        if (usage?.isPremium != true) {
            TextButton(onClick = picker.onUpgrade, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                Text(stringResource(R.string.voicevox_upgrade))
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
