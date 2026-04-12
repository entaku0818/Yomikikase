package com.entaku.VoiceYourText.screenshot

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.entaku.VoiceYourText.ui.theme.VoiceYourTextTheme

class ScreenshotActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val initialScreen = intent.getIntExtra("screen", 0).coerceIn(0, 3)
        setContent {
            VoiceYourTextTheme {
                ScreenshotFlow(initialScreen = initialScreen)
            }
        }
    }
}

@Composable
private fun ScreenshotFlow(initialScreen: Int = 0) {
    var currentScreen by remember { mutableIntStateOf(initialScreen) }
    val interactionSource = remember { MutableInteractionSource() }

    Box(modifier = Modifier.fillMaxSize()) {
        when (currentScreen) {
            0 -> ScreenshotPage(
                caption = "テキストを入力して\n即座に読み上げ",
                selectedTab = 0
            ) { SpeechScreenMock() }

            1 -> ScreenshotPage(
                caption = "読み上げた内容を\n履歴から再生",
                selectedTab = 1
            ) { HistoryScreenMock() }

            2 -> ScreenshotPage(
                caption = "PDFをそのまま\n音声で読み上げ",
                selectedTab = 2
            ) { PdfScreenMock() }

            3 -> ScreenshotPage(
                caption = "速さ・言語を\n自由にカスタマイズ",
                selectedTab = 3
            ) { SettingsScreenMock() }
        }

        // Transparent overlay on top to capture taps regardless of child composables
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clickable(
                    interactionSource = interactionSource,
                    indication = null
                ) { currentScreen = (currentScreen + 1) % 4 }
        )
    }
}

// ---------------------------------------------------------------------------
// Page wrapper: caption + content + bottom nav
// ---------------------------------------------------------------------------

@Composable
private fun ScreenshotPage(
    caption: String,
    selectedTab: Int,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        Text(
            text = caption,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            lineHeight = 36.sp,
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(horizontal = 24.dp, vertical = 32.dp)
        )

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
        ) {
            content()
        }

        MockBottomNav(selectedTab = selectedTab)
    }
}

@Composable
private fun MockBottomNav(selectedTab: Int) {
    data class TabItem(val icon: ImageVector, val label: String, val index: Int)

    val tabs = listOf(
        TabItem(Icons.Default.Mic, "読み上げ", 0),
        TabItem(Icons.Default.History, "履歴", 1),
        TabItem(Icons.Default.PictureAsPdf, "PDF", 2),
        TabItem(Icons.Default.Settings, "設定", 3)
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .padding(vertical = 8.dp, horizontal = 4.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        tabs.forEach { tab ->
            val isSelected = tab.index == selectedTab
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.weight(1f)
            ) {
                if (isSelected) {
                    Surface(
                        shape = RoundedCornerShape(50),
                        color = MaterialTheme.colorScheme.secondaryContainer
                    ) {
                        Icon(
                            imageVector = tab.icon,
                            contentDescription = tab.label,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                            tint = MaterialTheme.colorScheme.onSecondaryContainer
                        )
                    }
                } else {
                    Icon(
                        imageVector = tab.icon,
                        contentDescription = tab.label,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )
                }
                Text(
                    text = tab.label,
                    fontSize = 12.sp,
                    color = if (isSelected) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Screen 1: Speech – highlight playback in progress
// ---------------------------------------------------------------------------

@Composable
private fun SpeechScreenMock() {
    val sampleText = "国境の長いトンネルを抜けると雪国であった。夜の底が白くなった。信号所に汽車が止まった。"
    val highlightWord = "トンネル"

    val annotated = buildAnnotatedString {
        val idx = sampleText.indexOf(highlightWord)
        if (idx >= 0) {
            append(sampleText.substring(0, idx))
            withStyle(
                SpanStyle(
                    background = Color(0xFFFF9800),
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            ) { append(highlightWord) }
            append(sampleText.substring(idx + highlightWord.length))
        } else {
            append(sampleText)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // TopAppBar mock
        Text(
            text = "Voice Your Text",
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(horizontal = 16.dp, vertical = 14.dp)
        )

        // Text input with highlighted content
        Surface(
            shape = RoundedCornerShape(12.dp),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
            modifier = Modifier
                .fillMaxWidth()
                .height(150.dp)
        ) {
            Box(modifier = Modifier.padding(12.dp)) {
                Text(text = annotated, fontSize = 16.sp, lineHeight = 24.sp)
            }
        }

        // Language card
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        "言語",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "日本語",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                }
                Icon(Icons.Default.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        // Speed card
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        "速さ",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "x1.0",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Slider(
                    value = 0.5f,
                    onValueChange = {},
                    modifier = Modifier.fillMaxWidth()
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("遅い", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("標準 1.0", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("速い", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Stop button (playing state)
        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Button(
                onClick = {},
                modifier = Modifier.size(80.dp),
                shape = CircleShape,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error
                )
            ) {
                Icon(Icons.Default.Stop, contentDescription = "停止", modifier = Modifier.size(36.dp))
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ---------------------------------------------------------------------------
// Screen 2: History – demo list items
// ---------------------------------------------------------------------------

@Composable
private fun HistoryScreenMock() {
    val items = listOf(
        "国境の長いトンネルを抜けると雪国であった。",
        "吾輩は猫である。名前はまだない。",
        "親譲の無鉄砲で小供の時から損ばかりしている。",
        "恥の多い生涯を送って来ました。自分には、人間の生活というものが見当つかないのです。",
        "山路を登りながら、こう考えた。智に働けば角が立つ。情に棹させば流される。"
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(items.size) { i ->
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = items[i],
                        modifier = Modifier.weight(1f),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Icon(
                        Icons.Default.PlayArrow,
                        contentDescription = "再生",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "削除",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Screen 3: PDF – mock viewer with progress
// ---------------------------------------------------------------------------

@Composable
private fun PdfScreenMock() {
    val pdfLines = listOf(
        "第一章　雪国",
        "",
        "国境の長いトンネルを抜けると雪国であった。夜の底が白くなった。信号所に汽車が止まった。",
        "",
        "向側の座席から娘が立って来て、島村の前のガラス窓を落した。雪の寒さが流れ込んで来た。",
        "",
        "娘は窓いっぱいに乗り出して、遠くへ叫ぶように、",
        "「駅長さあん、駅長さあん。」",
        "",
        "暗の中でも声は澄んでいた。",
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // TopAppBar mock
        Text(
            text = "PDF",
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(horizontal = 16.dp, vertical = 14.dp)
        )

        // Progress bar
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    "1 / 3 ページ",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    "33%",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            LinearProgressIndicator(
                progress = { 0.33f },
                modifier = Modifier.fillMaxWidth()
            )
        }

        // PDF page mock
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = Color.White,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .weight(1f)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                pdfLines.forEachIndexed { idx, line ->
                    if (idx == 2) {
                        // Highlight the currently reading sentence
                        val readingText = "国境の長いトンネルを抜けると雪国であった。"
                        val rest = line.removePrefix(readingText)
                        val annotated = buildAnnotatedString {
                            withStyle(
                                SpanStyle(
                                    background = Color(0xFFBBDEFB),
                                    color = Color(0xFF1565C0)
                                )
                            ) { append(readingText) }
                            append(rest)
                        }
                        Text(text = annotated, style = MaterialTheme.typography.bodyMedium, lineHeight = 22.sp)
                    } else if (idx == 0) {
                        Text(
                            text = line,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                    } else {
                        Text(
                            text = line,
                            style = MaterialTheme.typography.bodyMedium,
                            lineHeight = 22.sp
                        )
                    }
                }
            }
        }

        // Playback controls
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(horizontal = 32.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.Center
        ) {
            Button(
                onClick = {},
                modifier = Modifier.size(64.dp),
                shape = CircleShape,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error
                )
            ) {
                Icon(Icons.Default.Stop, contentDescription = "停止", modifier = Modifier.size(28.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Screen 4: Settings – demo values
// ---------------------------------------------------------------------------

@Composable
private fun SettingsScreenMock() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // TopAppBar mock
        Text(
            text = "設定",
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(horizontal = 16.dp, vertical = 14.dp)
        )

        Column(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Voice settings card
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        "音声設定",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )

                    HorizontalDivider()

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("デフォルト言語", style = MaterialTheme.typography.bodyMedium)
                        Text(
                            "日本語",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    HorizontalDivider()

                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("読み上げ速度", style = MaterialTheme.typography.bodyMedium)
                            Text(
                                "x1.2",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Slider(value = 0.57f, onValueChange = {}, modifier = Modifier.fillMaxWidth())
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("遅い", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("標準 1.0", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("速い", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    HorizontalDivider()

                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("声の高さ", style = MaterialTheme.typography.bodyMedium)
                            Text(
                                "x1.0",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Slider(value = 0.5f, onValueChange = {}, modifier = Modifier.fillMaxWidth())
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("低い", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("標準 1.0", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("高い", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }

            // App info card
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("アプリ情報", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    HorizontalDivider()
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("バージョン", style = MaterialTheme.typography.bodyMedium)
                        Text("1.0.0", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    HorizontalDivider()
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("対応言語", style = MaterialTheme.typography.bodyMedium)
                        Text("7言語", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}
