package com.entaku.VoiceYourText.tts

import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.Lifecycle
import androidx.compose.runtime.DisposableEffect
import android.speech.tts.TextToSpeech
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import com.entaku.VoiceYourText.file.FilePickerButton
import androidx.compose.material3.Button
import androidx.compose.material3.TextButton
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.DropdownMenu
import androidx.compose.material.icons.outlined.Bedtime
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.OutlinedButton
import androidx.compose.material.icons.filled.Pause
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.entaku.VoiceYourText.file.FilePickerButton
import com.entaku.VoiceYourText.file.SourceType
import com.entaku.VoiceYourText.file.TextFileReader
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SpeechScreen(
    viewModel: TtsViewModel,
    initialText: String = "",
    onTextConsumed: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val ttsState by viewModel.state.collectAsState()
    val sleepTimer by viewModel.sleepTimer.collectAsState()
    val highlight by viewModel.highlight.collectAsState()
    val speechRate by viewModel.speechRate.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    val isLanguageUnavailable by viewModel.isLanguageUnavailable.collectAsState()
    val isInitialized by viewModel.isInitialized.collectAsState()

    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    // 入力内容は ViewModel に持たせる（タブを移っても消えないように）
    val inputText by viewModel.draftText.collectAsState()
    var showLanguageSheet by remember { mutableStateOf(false) }
    var showVoiceSheet by remember { mutableStateOf(false) }
    val voiceOptions by viewModel.voiceOptions.collectAsState()
    val selectedVoiceName by viewModel.selectedVoiceName.collectAsState()

    // 端末の設定で音声データを追加して戻ってきたら、声の一覧を取り直す
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.refreshVoices()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Apply text from history selection
    LaunchedEffect(initialText) {
        if (initialText.isNotBlank()) {
            viewModel.setDraftText(initialText)
            onTextConsumed()
        }
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Voice Your Text",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 読み上げ中は入力欄の代わりに、読んでいる箇所をハイライトした本文を出す
            val isPlaying = ttsState == TtsState.SPEAKING || ttsState == TtsState.PAUSED
            val playingHere = highlight?.source ?: TtsViewModel.SOURCE_TEXT
            if (isPlaying && playingHere == TtsViewModel.SOURCE_TEXT) {
                HighlightedText(
                    text = highlight?.text ?: inputText,
                    range = highlight?.range,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                )
            } else OutlinedTextField(
                value = inputText,
                onValueChange = viewModel::setDraftText,
                label = { Text("読み上げるテキストを入力") },
                placeholder = { Text("ここにテキストを入力してください…") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                shape = RoundedCornerShape(12.dp),
                maxLines = 8,
                trailingIcon = {
                    FilePickerButton(
                        onFilePicked = { uri ->
                            coroutineScope.launch {
                                TextFileReader.read(context, uri)
                                    .onSuccess { imported ->
                                        viewModel.setDraftText(imported.content)
                                        viewModel.saveImportedFile(
                                            title = imported.fileName,
                                            content = imported.content,
                                            sourceType = SourceType.TXT_IMPORT
                                        )
                                    }
                            }
                        }
                    )
                }
            )

            // 言語と声（縦の余白が少ないので1行に並べる）
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SettingChip(
                    label = "言語",
                    value = selectedLanguage.displayName,
                    onClick = { showLanguageSheet = true },
                    modifier = Modifier.weight(1f)
                )
                SettingChip(
                    label = "声",
                    value = voiceOptions.firstOrNull { it.name == selectedVoiceName }?.label ?: "標準",
                    onClick = { showVoiceSheet = true },
                    modifier = Modifier.weight(1f)
                )
            }

            if (showVoiceSheet) {
                VoiceBottomSheet(
                    options = voiceOptions,
                    selectedName = selectedVoiceName,
                    onSelect = viewModel::setVoice,
                    onAddVoices = {
                        runCatching {
                            context.startActivity(
                                Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }
                    },
                    onDismiss = { showVoiceSheet = false }
                )
            }

            if (isLanguageUnavailable) {
                // 端末に音声データが無い言語は既定の言語で読まれてしまうので、追加方法を案内する
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "${selectedLanguage.displayName} の音声データがこの端末にありません。追加するまでは端末の既定の言語で読み上げます。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                    TextButton(
                        onClick = {
                            runCatching {
                                context.startActivity(
                                    Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                            }
                        }
                    ) {
                        Text("音声データを追加する")
                    }
                }
            }

            if (showLanguageSheet) {
                LanguageBottomSheet(
                    selectedLanguage = selectedLanguage,
                    onLanguageSelected = { viewModel.setLanguage(it) },
                    onDismiss = { showLanguageSheet = false }
                )
            }

            // Speed control
            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "速さ",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "x${"%.1f".format(speechRate)}",
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    Slider(
                        value = speechRate,
                        onValueChange = { viewModel.setSpeechRate(it) },
                        valueRange = 0.5f..2.0f,
                        steps = 5,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "遅い",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "標準 1.0",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "速い",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Status indicator with retry
            if (ttsState == TtsState.ERROR) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "TTSエンジンの初期化に失敗しました",
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = TextAlign.Center
                    )
                    Button(
                        onClick = { viewModel.retryInit() },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer,
                            contentColor = MaterialTheme.colorScheme.onErrorContainer
                        )
                    ) {
                        Text("再試行")
                    }
                }
            }

            // 再生 / 一時停止・再開 / 停止
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically
            ) {
                when (ttsState) {
                    TtsState.SPEAKING, TtsState.PAUSED -> {
                        val isSpeaking = ttsState == TtsState.SPEAKING
                        Button(
                            onClick = { if (isSpeaking) viewModel.pause() else viewModel.resume() },
                            modifier = Modifier.size(80.dp),
                            shape = CircleShape
                        ) {
                            Icon(
                                imageVector = if (isSpeaking) Icons.Default.Pause else Icons.Default.PlayArrow,
                                contentDescription = if (isSpeaking) "一時停止" else "再開",
                                modifier = Modifier.size(36.dp)
                            )
                        }
                        OutlinedButton(
                            onClick = { viewModel.stop() },
                            modifier = Modifier.size(56.dp),
                            shape = CircleShape,
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Stop,
                                contentDescription = "停止",
                                modifier = Modifier.size(28.dp)
                            )
                        }
                        // 縦の余白が足りない端末でも潰れないよう、再生ボタンと同じ行に置く
                        SleepTimerButton(
                            sleepTimer = sleepTimer,
                            onSelect = viewModel::setSleepTimer
                        )
                    }
                    else -> {
                        Button(
                            onClick = { viewModel.speak(inputText) },
                            enabled = isInitialized && inputText.isNotBlank() && ttsState != TtsState.ERROR,
                            modifier = Modifier.size(80.dp),
                            shape = CircleShape
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = "再生",
                                modifier = Modifier.size(36.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/** スリープタイマーの設定ボタン（月アイコン＋残り時間）。iOS のミニプレイヤーのメニューと同じ選択肢。 */
@Composable
private fun SleepTimerButton(
    sleepTimer: SleepTimerState?,
    onSelect: (SleepTimerOption?) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier = modifier) {
        TextButton(onClick = { expanded = true }) {
            Icon(
                imageVector = if (sleepTimer == null) Icons.Outlined.Bedtime else Icons.Filled.Bedtime,
                contentDescription = "スリープタイマー",
                tint = if (sleepTimer == null) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.primary
            )
            if (sleepTimer != null) {
                Spacer(modifier = Modifier.width(4.dp))
                Text(text = sleepTimer.displayText, color = MaterialTheme.colorScheme.primary)
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            SleepTimerOption.PRESETS.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.title) },
                    onClick = {
                        onSelect(option)
                        expanded = false
                    }
                )
            }
            if (sleepTimer != null) {
                DropdownMenuItem(
                    text = { Text("タイマーを解除") },
                    onClick = {
                        onSelect(null)
                        expanded = false
                    }
                )
            }
        }
    }
}

@Composable
private fun SettingChip(label: String, value: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.weight(1f)) {
                Text(text = label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(text = value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, maxLines = 1)
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}
