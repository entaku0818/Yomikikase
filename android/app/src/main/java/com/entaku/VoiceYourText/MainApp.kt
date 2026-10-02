package com.entaku.VoiceYourText

import com.entaku.VoiceYourText.file.SourceType
import com.entaku.VoiceYourText.aozora.AozoraLibraryScreen
import com.entaku.VoiceYourText.home.HomeScreen
import androidx.activity.compose.BackHandler
import com.entaku.VoiceYourText.tts.TtsState
import com.entaku.VoiceYourText.tts.MiniPlayer
import androidx.compose.runtime.collectAsState
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
import androidx.compose.material.icons.filled.Home
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
    val nowPlaying by ttsViewModel.nowPlaying.collectAsState()
    val ttsState by ttsViewModel.state.collectAsState()
    var selectedTab by remember { mutableIntStateOf(HOME_TAB) }
    // ホームタブの中の画面（ホーム → テキスト / PDF）。共有で文章を受け取ったときはテキスト画面から始める
    var homeScreen by remember { mutableStateOf(if (initialSharedText.isNullOrBlank()) HomeDestination.HOME else HomeDestination.SPEECH) }
    LaunchedEffect(Unit) {
        if (!initialSharedText.isNullOrBlank()) ttsViewModel.setDraftText(initialSharedText)
    }
    fun openText(text: String) {
        ttsViewModel.setDraftText(text)
        selectedTab = HOME_TAB
        homeScreen = HomeDestination.SPEECH
    }
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
        if (selectedTab == SETTINGS_TAB) analytics.logEvent("view_settings")
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            Column {
            // 読み上げ元とは別の画面にいるときだけミニプレイヤーを出す
            val playing = nowPlaying
            val sourceScreen = if (playing?.source == TtsViewModel.SOURCE_PDF) HomeDestination.PDF else HomeDestination.SPEECH
            val isOnSource = selectedTab == HOME_TAB && homeScreen == sourceScreen
            if (playing != null && !isOnSource) {
                MiniPlayer(
                    nowPlaying = playing,
                    isSpeaking = ttsState == TtsState.SPEAKING,
                    onOpen = {
                        selectedTab = HOME_TAB
                        homeScreen = sourceScreen
                    },
                    onTogglePlay = {
                        if (ttsState == TtsState.SPEAKING) ttsViewModel.pause() else ttsViewModel.resume()
                    },
                    onClose = ttsViewModel::stop
                )
            }
            BannerAdView(placement = "main")
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == HOME_TAB,
                    onClick = {
                        // ホームタブをもう一度押したらホームに戻る
                        if (selectedTab == HOME_TAB) homeScreen = HomeDestination.HOME
                        selectedTab = HOME_TAB
                    },
                    icon = { Icon(Icons.Default.Home, contentDescription = "ホーム") },
                    label = { Text("ホーム") }
                )
                NavigationBarItem(
                    selected = selectedTab == MY_FILES_TAB,
                    onClick = { selectedTab = MY_FILES_TAB },
                    icon = { Icon(Icons.Default.Folder, contentDescription = "マイファイル") },
                    label = { Text("マイファイル") }
                )
                NavigationBarItem(
                    selected = selectedTab == SETTINGS_TAB,
                    onClick = { selectedTab = SETTINGS_TAB },
                    icon = { Icon(Icons.Default.Settings, contentDescription = "設定") },
                    label = { Text("設定") }
                )
            }
            }
        }
    ) { innerPadding ->
        val contentModifier = Modifier.padding(innerPadding)
        when (selectedTab) {
            HOME_TAB -> {
                // テキスト / PDF 画面ではシステムの戻るでホームに戻る
                BackHandler(enabled = homeScreen != HomeDestination.HOME) { homeScreen = HomeDestination.HOME }
                when (homeScreen) {
                    HomeDestination.HOME -> HomeScreen(
                        onOpenText = ::openText,
                        onOpenPdf = { homeScreen = HomeDestination.PDF },
                        onOpenAozora = { homeScreen = HomeDestination.AOZORA },
                        onSaveImported = ttsViewModel::saveImportedFile,
                        modifier = contentModifier
                    )
                    HomeDestination.SPEECH -> SpeechScreen(
                        viewModel = ttsViewModel,
                        onBack = { homeScreen = HomeDestination.HOME },
                        modifier = contentModifier
                    )
                    HomeDestination.AOZORA -> AozoraLibraryScreen(
                        onOpen = { work, text ->
                            ttsViewModel.saveImportedFile("${work.displayTitle}（${work.author}）", text, SourceType.AOZORA)
                            openText(text)
                        },
                        onBack = { homeScreen = HomeDestination.HOME },
                        modifier = contentModifier
                    )
                    HomeDestination.PDF -> PdfViewerScreen(
                        ttsViewModel = ttsViewModel,
                        onBack = { homeScreen = HomeDestination.HOME },
                        modifier = contentModifier
                    )
                }
            }
            MY_FILES_TAB -> MyFilesScreen(
                onOpenFile = ::openText,
                modifier = contentModifier
            )
            SETTINGS_TAB -> SettingsScreen(
                viewModel = ttsViewModel,
                modifier = contentModifier
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

/** ホームタブの中の画面 */
private enum class HomeDestination { HOME, SPEECH, PDF, AOZORA }

private const val HOME_TAB = 0
private const val MY_FILES_TAB = 1
private const val SETTINGS_TAB = 2
private val TAB_NAMES = listOf("home", "my_files", "settings")
