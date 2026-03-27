package com.entaku.VoiceYourText

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.entaku.VoiceYourText.settings.SettingsScreen
import com.entaku.VoiceYourText.tts.HistoryScreen
import com.entaku.VoiceYourText.tts.SpeechScreen
import com.entaku.VoiceYourText.tts.TtsViewModel

@Composable
fun MainApp(initialSharedText: String? = null) {
    val ttsViewModel: TtsViewModel = viewModel()
    var selectedTab by remember { mutableIntStateOf(0) }
    var pendingText by remember { mutableStateOf(initialSharedText ?: "") }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Mic, contentDescription = "読み上げ") },
                    label = { Text("読み上げ") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.History, contentDescription = "履歴") },
                    label = { Text("履歴") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.Settings, contentDescription = "設定") },
                    label = { Text("設定") }
                )
            }
        }
    ) { innerPadding ->
        when (selectedTab) {
            0 -> SpeechScreen(
                viewModel = ttsViewModel,
                initialText = pendingText,
                onTextConsumed = { pendingText = "" },
                modifier = Modifier.padding(innerPadding)
            )
            1 -> HistoryScreen(
                viewModel = ttsViewModel,
                onSelectText = { text ->
                    pendingText = text
                    selectedTab = 0
                },
                modifier = Modifier.padding(innerPadding)
            )
            2 -> SettingsScreen(
                viewModel = ttsViewModel,
                modifier = Modifier.padding(innerPadding)
            )
        }
    }
}
