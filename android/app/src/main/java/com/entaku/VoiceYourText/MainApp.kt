package com.entaku.VoiceYourText

import com.entaku.VoiceYourText.ads.AppOpenAdManager
import kotlinx.coroutines.flow.map
import com.entaku.VoiceYourText.file.SavedFileRepository
import com.entaku.VoiceYourText.billing.PaywallScreen
import com.entaku.VoiceYourText.billing.FileLimits
import com.entaku.VoiceYourText.billing.PremiumManager
import com.entaku.VoiceYourText.onboarding.OnboardingScreen
import com.entaku.VoiceYourText.onboarding.OnboardingPrefs
import androidx.compose.ui.res.stringResource
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
import com.entaku.VoiceYourText.ui.localizedMonthDayFormat
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

    // 初回起動はオンボーディングから
    var showOnboarding by remember { mutableStateOf(OnboardingPrefs.shouldShow(context)) }
    var showReviewPrompt by remember { mutableStateOf(false) }
    // 課金: プレミアムなら広告を出さない。無料版はファイル5件まで（iOS と同じ）
    val isPremium by PremiumManager.isPremium.collectAsState()
    val fileCount by remember { SavedFileRepository(context).getAll().map(FileLimits::countedFiles) }.collectAsState(initial = 0)
    var paywallSource by remember { mutableStateOf<String?>(null) }
    // 読み上げ側（キャラ音声の上限など）から課金画面を出してほしいと言われたら出す
    val paywallRequest by ttsViewModel.paywallRequest.collectAsState()
    LaunchedEffect(paywallRequest) {
        paywallRequest?.let {
            paywallSource = it
            ttsViewModel.consumePaywallRequest()
        }
    }
    val voicevoxQuotaStop by ttsViewModel.voicevoxQuotaStop.collectAsState()
    var showFileLimit by remember { mutableStateOf(false) }
    fun guardNewFile(block: () -> Unit) {
        if (PremiumManager.isAvailable && FileLimits.hasReachedLimit(fileCount, isPremium)) showFileLimit = true else block()
    }
    var showFeedback by remember { mutableStateOf(false) }
    val reviewRequester = remember { ReviewRequester(analytics) }

    // レビュー依頼（起動時判定）。2回目以降の起動・90日間隔で満足度を1問だけ聞く（iOS と同じ）
    LaunchedEffect(Unit) {
        if (!isColdStart) return@LaunchedEffect
        val store = ReviewPromptStore(
            context.getSharedPreferences(ReviewPromptStore.PREFS_NAME, Context.MODE_PRIVATE)
        )
        val launchCount = store.incrementLaunchCount()
        // 起動時の全画面広告（3回に1回・プレミアムとオンボーディング中は出さない）。出した起動ではレビュー依頼を出さない
        val didShowAppOpenAd = context.findActivity()?.let { activity ->
            AppOpenAdManager.showOnColdStartIfEligible(
                activity,
                isPremium = PremiumManager.isPremium.value,
                hasCompletedOnboarding = !showOnboarding,
            )
        } ?: false
        if (ReviewPolicy.shouldPrompt(launchCount, didShowAppOpenAd, store.lastPromptAtMillis, System.currentTimeMillis())) {
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

    if (showOnboarding) {
        OnboardingScreen(ttsViewModel = ttsViewModel, onFinish = { showOnboarding = false })
        return
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
            if (!isPremium) BannerAdView(placement = "main")
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == HOME_TAB,
                    onClick = {
                        // ホームタブをもう一度押したらホームに戻る
                        if (selectedTab == HOME_TAB) homeScreen = HomeDestination.HOME
                        selectedTab = HOME_TAB
                    },
                    icon = { Icon(Icons.Default.Home, contentDescription = stringResource(R.string.tab_home)) },
                    label = { Text(stringResource(R.string.tab_home)) }
                )
                NavigationBarItem(
                    selected = selectedTab == MY_FILES_TAB,
                    onClick = { selectedTab = MY_FILES_TAB },
                    icon = { Icon(Icons.Default.Folder, contentDescription = stringResource(R.string.tab_my_files)) },
                    label = { Text(stringResource(R.string.tab_my_files)) }
                )
                NavigationBarItem(
                    selected = selectedTab == SETTINGS_TAB,
                    onClick = { selectedTab = SETTINGS_TAB },
                    icon = { Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.tab_settings)) },
                    label = { Text(stringResource(R.string.tab_settings)) }
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
                        modifier = contentModifier,
                        guardNewFile = ::guardNewFile,
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
                onOpenPremium = { paywallSource = "settings" },
                modifier = contentModifier
            )
        }
    }

    paywallSource?.let { source ->
        PaywallScreen(source = source, onDismiss = { paywallSource = null })
    }

    voicevoxQuotaStop?.let { stop ->
        // キャラ音声が今月の上限で止まった。続きは端末の音声で読める
        AlertDialog(
            onDismissRequest = ttsViewModel::dismissVoicevoxQuotaStop,
            title = { Text(stringResource(R.string.voicevox_quota_title)) },
            text = {
                Text(stringResource(R.string.voicevox_quota_message, localizedMonthDayFormat().format(java.util.Date.from(stop.usage.resetAt))))
            },
            confirmButton = {
                TextButton(onClick = ttsViewModel::continueWithDeviceVoice) {
                    Text(stringResource(R.string.voicevox_continue_device))
                }
            },
            dismissButton = {
                if (!stop.usage.isPremium) {
                    TextButton(onClick = {
                        ttsViewModel.dismissVoicevoxQuotaStop()
                        paywallSource = "voicevox_quota"
                    }) { Text(stringResource(R.string.voicevox_see_premium)) }
                } else {
                    TextButton(onClick = ttsViewModel::dismissVoicevoxQuotaStop) { Text(stringResource(R.string.common_cancel)) }
                }
            }
        )
    }

    if (showFileLimit) {
        AlertDialog(
            onDismissRequest = { showFileLimit = false },
            title = { Text(stringResource(R.string.file_limit_title)) },
            text = { Text(stringResource(R.string.file_limit_message, FileLimits.MAX_FREE_FILES)) },
            confirmButton = {
                TextButton(onClick = {
                    showFileLimit = false
                    paywallSource = "file_limit"
                }) { Text(stringResource(R.string.file_limit_upgrade)) }
            },
            dismissButton = { TextButton(onClick = { showFileLimit = false }) { Text(stringResource(R.string.common_cancel)) } }
        )
    }

    if (showReviewPrompt) {
        AlertDialog(
            onDismissRequest = {},
            properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false),
            title = { Text(stringResource(R.string.review_title)) },
            text = { Text(stringResource(R.string.review_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showReviewPrompt = false
                    reviewRequester.onAnswer(satisfied = true, activity = context.findActivity())
                }) { Text(stringResource(R.string.common_yes)) }
            },
            dismissButton = {
                TextButton(onClick = {
                    showReviewPrompt = false
                    reviewRequester.onAnswer(satisfied = false, activity = context.findActivity())
                    showFeedback = true
                }) { Text(stringResource(R.string.review_no)) }
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
