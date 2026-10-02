package com.entaku.VoiceYourText

import kotlinx.coroutines.delay
import com.entaku.VoiceYourText.review.ReviewRequester
import com.entaku.VoiceYourText.review.ReviewPromptStore
import com.entaku.VoiceYourText.review.ReviewPolicy
import com.entaku.VoiceYourText.feedback.FeedbackDialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.material3.TextButton
import androidx.compose.material3.AlertDialog
import android.content.ContextWrapper
import android.content.Context
import android.app.Activity
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.entaku.VoiceYourText.ads.BannerAdView
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.entaku.VoiceYourText.file.MyFilesScreen
import com.entaku.VoiceYourText.pdf.PdfViewerScreen
import com.entaku.VoiceYourText.settings.SettingsScreen
import com.entaku.VoiceYourText.tts.SpeechScreen
import com.entaku.VoiceYourText.tts.TtsViewModel

@Composable
fun MainApp(initialSharedText: String? = null, isColdStart: Boolean = false) {
    val ttsViewModel: TtsViewModel = viewModel()
    val context = LocalContext.current
    var selectedTab by remember { mutableIntStateOf(0) }
    var pendingText by remember { mutableStateOf(initialSharedText ?: "") }
    val analytics = remember { AnalyticsClient.get(context) }

    var showReviewPrompt by remember { mutableStateOf(false) }
    var showFeedback by remember { mutableStateOf(false) }
    val reviewRequester = remember { ReviewRequester(analytics) }

    // レビュー依頼（起動時判定）。2回目以降の起動・90日間隔で満足度を1問だけ聞く（iOS と同じ）
    LaunchedEffect(Unit) {
        if (!isColdStart) return@LaunchedEffect
        val store = ReviewPromptStore(
            context.getSharedPreferences(ReviewPromptStore.PREFS_NAME, Context.MODE_PRIVATE)
        )
        val launchCount = store.incrementLaunchCount()
        // 起動時広告はまだ無いので didShowAppOpenAd は常に false（#150 で広告を入れたら渡す）
        if (ReviewPolicy.shouldPrompt(launchCount, false, store.lastPromptAtMillis, System.currentTimeMillis())) {
            delay(ReviewPolicy.DELAY_MILLIS)
            store.markPrompted(System.currentTimeMillis())
            reviewRequester.onPromptShown(launchCount)
            showReviewPrompt = true
        }
    }

    // iOS と同じ tab_clicked / view_settings を送る
    LaunchedEffect(selectedTab) {
        analytics.logEvent(
            "tab_clicked",
            mapOf("tab_name" to TAB_NAMES[selectedTab], "screen" to "main_tab_view")
        )
        if (selectedTab == 3) analytics.logEvent("view_settings")
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            Column {
            BannerAdView(placement = "main")
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
                    icon = { Icon(Icons.Default.Folder, contentDescription = "マイファイル") },
                    label = { Text("マイファイル") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.PictureAsPdf, contentDescription = "PDF") },
                    label = { Text("PDF") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Default.Settings, contentDescription = "設定") },
                    label = { Text("設定") }
                )
            }
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
            1 -> MyFilesScreen(
                onOpenFile = { text ->
                    pendingText = text
                    selectedTab = 0
                },
                modifier = Modifier.padding(innerPadding)
            )
            2 -> PdfViewerScreen(
                ttsViewModel = ttsViewModel,
                modifier = Modifier.padding(innerPadding)
            )
            3 -> SettingsScreen(
                viewModel = ttsViewModel,
                modifier = Modifier.padding(innerPadding)
            )
        }
    }

    if (showReviewPrompt) {
        AlertDialog(
            onDismissRequest = {},
            properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false),
            title = { Text("このアプリについて") },
            text = { Text("読み上げナレーターに満足していますか？") },
            confirmButton = {
                TextButton(onClick = {
                    showReviewPrompt = false
                    reviewRequester.onAnswer(satisfied = true, activity = context.findActivity())
                }) { Text("はい") }
            },
            dismissButton = {
                TextButton(onClick = {
                    showReviewPrompt = false
                    reviewRequester.onAnswer(satisfied = false, activity = context.findActivity())
                    showFeedback = true
                }) { Text("いいえ、フィードバックを送信") }
            }
        )
    }

    if (showFeedback) {
        FeedbackDialog(onDismiss = { showFeedback = false })
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private val TAB_NAMES = listOf("speech", "my_files", "pdf", "settings")
