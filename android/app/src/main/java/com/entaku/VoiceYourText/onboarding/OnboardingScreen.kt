package com.entaku.VoiceYourText.onboarding

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.edit
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.entaku.VoiceYourText.tts.TtsState
import com.entaku.VoiceYourText.tts.TtsViewModel
import kotlinx.coroutines.launch

/** オンボーディングを見終えたか（初回起動だけ出す） */
object OnboardingPrefs {
    private const val PREFS = "onboarding"
    private const val KEY_COMPLETED = "completed"

    fun isCompleted(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_COMPLETED, false)

    fun markCompleted(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putBoolean(KEY_COMPLETED, true) }

    /**
     * 出すかどうか。オンボーディングは 1.5.0 で入ったので、それより前から使っている人
     * （起動回数の記録がある / マイファイルのデータベースがある）には出さず、見たことにする。
     */
    fun shouldShow(context: Context): Boolean {
        if (isCompleted(context)) return false
        val launched = context.getSharedPreferences("review_request", Context.MODE_PRIVATE).getInt("launch_count", 0) > 0
        val hasFiles = context.getDatabasePath("voiceyourtext.db").exists()
        if (launched || hasFiles) {
            markCompleted(context)
            return false
        }
        return true
    }
}

/**
 * 初回起動のオンボーディング（iOS `Features/Onboarding/` 相当の3ステップ）。
 * ようこそ → サンプルの読み上げを試す → できることの紹介。イベント名は iOS と同じ。
 */
@Composable
fun OnboardingScreen(ttsViewModel: TtsViewModel, onFinish: () -> Unit) {
    val context = LocalContext.current
    val analytics = remember { AnalyticsClient.get(context) }
    val pager = rememberPagerState(pageCount = { 3 })
    val scope = rememberCoroutineScope()
    val ttsState by ttsViewModel.state.collectAsState()
    var hasPlayed by remember { mutableStateOf(false) }
    var hadSpoken by remember { mutableStateOf(false) }

    LaunchedEffect(pager.currentPage) {
        analytics.logEvent("onboarding_step_view", mapOf("step" to pager.currentPage))
    }
    // サンプルを最後まで聴いたら完了として送る
    LaunchedEffect(ttsState) {
        if (ttsState == TtsState.SPEAKING) hadSpoken = true
        if (hadSpoken && ttsState == TtsState.IDLE) {
            hadSpoken = false
            analytics.logEvent("onboarding_demo_completed")
        }
    }

    fun finish(skipped: Boolean) {
        ttsViewModel.stop()
        if (skipped) analytics.logEvent("onboarding_skipped", mapOf("step" to pager.currentPage))
        else analytics.logEvent("onboarding_completed", mapOf("completed_demo" to if (hasPlayed) 1 else 0))
        OnboardingPrefs.markCompleted(context)
        onFinish()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Row(modifier = Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.End) {
            if (pager.currentPage < 2) {
                TextButton(onClick = { finish(skipped = true) }) { Text(stringResource(R.string.onboarding_skip)) }
            } else {
                Spacer(Modifier.height(48.dp))
            }
        }
        HorizontalPager(state = pager, modifier = Modifier.weight(1f)) { page ->
            Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                when (page) {
                    0 -> WelcomeStep()
                    1 -> DemoStep(
                        isSpeaking = ttsState == TtsState.SPEAKING,
                        hasPlayed = hasPlayed,
                        onPlay = {
                            hasPlayed = true
                            analytics.logEvent("onboarding_demo_played", mapOf("demo_type" to "text"))
                            ttsViewModel.speak(context.getString(R.string.onboarding_demo_sample), saveToMyFiles = false)
                        },
                        onStop = ttsViewModel::stop,
                    )
                    else -> FeaturesStep()
                }
            }
        }
        PageDots(current = pager.currentPage, count = 3)
        Button(
            onClick = {
                if (pager.currentPage < 2) {
                    ttsViewModel.stop()
                    scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                } else {
                    finish(skipped = false)
                }
            },
            modifier = Modifier.fillMaxWidth().padding(24.dp).height(52.dp)
        ) {
            Text(
                stringResource(
                    when (pager.currentPage) {
                        0 -> R.string.onboarding_start
                        1 -> R.string.onboarding_next
                        else -> R.string.onboarding_finish
                    }
                )
            )
        }
    }
}

@Composable
private fun WelcomeStep() {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Box(
            modifier = Modifier.size(96.dp).background(MaterialTheme.colorScheme.primary, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.GraphicEq, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(56.dp))
        }
        Text(stringResource(R.string.app_name), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            stringResource(R.string.onboarding_welcome_body),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun DemoStep(isSpeaking: Boolean, hasPlayed: Boolean, onPlay: () -> Unit, onStop: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.onboarding_demo_title), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.onboarding_demo_subtitle), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.onboarding_demo_sample), modifier = Modifier.padding(20.dp), style = MaterialTheme.typography.bodyMedium)
        }
        Button(onClick = if (isSpeaking) onStop else onPlay, shape = CircleShape) {
            Icon(if (isSpeaking) Icons.Default.Stop else Icons.Default.PlayArrow, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(if (isSpeaking) R.string.common_stop else R.string.pdf_read_aloud))
        }
        if (hasPlayed && !isSpeaking) {
            Text(stringResource(R.string.onboarding_demo_done), color = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun FeaturesStep() {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.onboarding_features_title), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.onboarding_features_subtitle), color = MaterialTheme.colorScheme.onSurfaceVariant)
        FeatureRow(Icons.Default.PictureAsPdf, R.string.onboarding_feature_pdf_title, R.string.onboarding_feature_pdf_body)
        FeatureRow(Icons.Default.Language, R.string.onboarding_feature_web_title, R.string.onboarding_feature_web_body)
        FeatureRow(Icons.AutoMirrored.Filled.MenuBook, R.string.onboarding_feature_book_title, R.string.onboarding_feature_book_body)
        FeatureRow(Icons.Default.DocumentScanner, R.string.onboarding_feature_scan_title, R.string.onboarding_feature_scan_body)
    }
}

@Composable
private fun FeatureRow(icon: ImageVector, title: Int, body: Int) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(
            modifier = Modifier.size(48.dp).background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        }
        Column {
            Text(stringResource(title), style = MaterialTheme.typography.titleSmall)
            Text(stringResource(body), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun PageDots(current: Int, count: Int) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        repeat(count) { i ->
            Box(
                modifier = Modifier
                    .padding(4.dp)
                    .size(if (i == current) 10.dp else 8.dp)
                    .background(
                        if (i == current) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
                        CircleShape
                    )
            )
        }
    }
}
