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
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.entaku.VoiceYourText.ui.theme.VoiceYourTextTheme

class ScreenshotActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // 宣材スクショ用に実機ステータスバー/ナビバーを隠す（ノイズ除去）
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        val initialScreen = intent.getIntExtra("screen", 0).coerceIn(0, 3)
        val lang = intent.getStringExtra("lang") ?: "ja"
        setContent {
            VoiceYourTextTheme {
                ScreenshotFlow(initialScreen = initialScreen, lang = lang)
            }
        }
    }
}

// 言語別プロモキャプション（本文UIは日本語デモのまま＝従来踏襲、キャプションのみローカライズ）
private val CAPTIONS: Map<String, List<String>> = mapOf(
    "ja" to listOf("テキストを入力して\n即座に読み上げ", "読み上げた内容を\n履歴から再生", "PDFをそのまま\n音声で読み上げ", "速さ・言語を\n自由にカスタマイズ"),
    "en" to listOf("Type text and\nread aloud instantly", "Replay anything\nfrom history", "Read PDFs aloud\nas they are", "Customize speed\n& language freely"),
    "es" to listOf("Escribe y\nescucha al instante", "Reproduce desde\ntu historial", "Lee tus PDF\nen voz alta", "Ajusta velocidad\ne idioma"),
    "fr" to listOf("Saisissez et\nécoutez aussitôt", "Réécoutez depuis\nl'historique", "Lisez vos PDF\nà voix haute", "Personnalisez vitesse\net langue"),
    "ko" to listOf("텍스트를 입력하면\n바로 읽어줘요", "기록에서\n다시 재생", "PDF를 그대로\n음성으로 읽기", "속도·언어를\n자유롭게 설정"),
    "zh" to listOf("输入文字\n即刻朗读", "从历史记录\n重新播放", "直接朗读\nPDF 文档", "自由调整\n语速和语言")
)

// サブタイトルは主要2言語のみ（iOSと同じ方針）。他言語は null（見出しのみ）
private val SUBTITLES: Map<String, List<String>> = mapOf(
    "ja" to listOf("入力した文章を、その場で音声に", "聞いた文章は履歴から何度でも", "長いPDFも、まるごと音声で", "声・速度・言語を自分好みに"),
    "en" to listOf("Turn typed text into speech", "Replay past texts anytime", "Whole PDFs, read aloud", "Voice, speed & language your way")
)

// 下部ナビのラベル（PDFは共通）
private val NAV_LABELS: Map<String, List<String>> = mapOf(
    "ja" to listOf("読み上げ", "履歴", "PDF", "設定"),
    "en" to listOf("Read", "History", "PDF", "Settings"),
    "es" to listOf("Leer", "Historial", "PDF", "Ajustes"),
    "fr" to listOf("Lire", "Historique", "PDF", "Réglages"),
    "ko" to listOf("읽기", "기록", "PDF", "설정"),
    "zh" to listOf("朗读", "历史", "PDF", "设置")
)

// 画面内テキストも言語に合わせてローカライズ
private data class SsLoc(
    val langLabel: String, val langValue: String,
    val speed: String, val slow: String, val normal: String, val fast: String,
    val sampleText: String, val highlight: String,
    val history: List<String>,
    val pdfPageLabel: String, val pdfPercent: String, val pdfTitle: String, val pdfBody: List<String>, val pdfHighlight: String,
    val settings: String, val voiceSettings: String, val defaultLang: String,
    val readSpeed: String, val pitch: String, val pitchLow: String, val pitchHigh: String,
    val appInfo: String, val version: String, val supportedLangs: String, val langCount: String
)

private val LOC: Map<String, SsLoc> = mapOf(
    "ja" to SsLoc(
        "言語", "日本語", "速さ", "遅い", "標準 1.0", "速い",
        "国境の長いトンネルを抜けると雪国であった。夜の底が白くなった。信号所に汽車が止まった。", "トンネル",
        listOf("国境の長いトンネルを抜けると雪国であった。", "吾輩は猫である。名前はまだない。", "親譲の無鉄砲で小供の時から損ばかりしている。", "恥の多い生涯を送って来ました。", "山路を登りながら、こう考えた。"),
        "1 / 3 ページ", "33%", "第一章　雪国",
        listOf("国境の長いトンネルを抜けると雪国であった。夜の底が白くなった。", "向側の座席から娘が立って来て、島村の前のガラス窓を落した。", "「駅長さあん、駅長さあん。」", "暗の中でも声は澄んでいた。"),
        "国境の長いトンネルを抜けると雪国であった。",
        "設定", "音声設定", "デフォルト言語", "読み上げ速度", "声の高さ", "低い", "高い", "アプリ情報", "バージョン", "対応言語", "7言語"
    ),
    "en" to SsLoc(
        "Language", "English", "Speed", "Slow", "Normal 1.0", "Fast",
        "It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness.", "wisdom",
        listOf("It was the best of times, it was the worst of times.", "Call me Ishmael.", "It is a truth universally acknowledged...", "All happy families are alike.", "The quick brown fox jumps over the lazy dog."),
        "Page 1 / 3", "33%", "Chapter 1",
        listOf("It was the best of times, it was the worst of times, it was the age of wisdom.", "It was the age of foolishness, it was the epoch of belief.", "It was the season of Light, it was the season of Darkness.", "It was the spring of hope, it was the winter of despair."),
        "It was the best of times, it was the worst of times,",
        "Settings", "Voice settings", "Default language", "Reading speed", "Pitch", "Low", "High", "App info", "Version", "Languages", "7 languages"
    ),
    "es" to SsLoc(
        "Idioma", "Español", "Velocidad", "Lenta", "Normal 1.0", "Rápida",
        "En un lugar de la Mancha, de cuyo nombre no quiero acordarme, vivía un hidalgo.", "Mancha",
        listOf("En un lugar de la Mancha, de cuyo nombre no quiero acordarme.", "Cien años de soledad.", "Érase una vez un mundo lleno de historias.", "El veloz murciélago hindú comía feliz.", "La lectura en voz alta es un placer."),
        "Página 1 / 3", "33%", "Capítulo 1",
        listOf("En un lugar de la Mancha, de cuyo nombre no quiero acordarme,", "vivía no hace mucho tiempo un hidalgo de los de lanza en astillero.", "Frisaba la edad de nuestro hidalgo con los cincuenta años.", "Era de complexión recia, seco de carnes, enjuto de rostro."),
        "En un lugar de la Mancha, de cuyo nombre no quiero acordarme,",
        "Ajustes", "Ajustes de voz", "Idioma predeterminado", "Velocidad de lectura", "Tono", "Bajo", "Alto", "Información", "Versión", "Idiomas", "7 idiomas"
    ),
    "fr" to SsLoc(
        "Langue", "Français", "Vitesse", "Lent", "Normal 1.0", "Rapide",
        "Longtemps, je me suis couché de bonne heure. Parfois, à peine ma bougie éteinte, mes yeux se fermaient.", "Longtemps",
        listOf("Longtemps, je me suis couché de bonne heure.", "Aujourd'hui, le soleil brille sur la ville.", "La lecture à voix haute est un plaisir.", "Le vif renard brun saute par-dessus le chien.", "Il était une fois un grand voyage."),
        "Page 1 / 3", "33%", "Chapitre 1",
        listOf("Longtemps, je me suis couché de bonne heure.", "Parfois, à peine ma bougie éteinte, mes yeux se fermaient si vite.", "que je n'avais pas le temps de me dire : « Je m'endors. »", "Et, une demi-heure après, la pensée me réveillait."),
        "Longtemps, je me suis couché de bonne heure.",
        "Réglages", "Réglages vocaux", "Langue par défaut", "Vitesse de lecture", "Hauteur", "Grave", "Aigu", "À propos", "Version", "Langues", "7 langues"
    ),
    "ko" to SsLoc(
        "언어", "한국어", "속도", "느림", "표준 1.0", "빠름",
        "국경의 긴 터널을 빠져나오니 눈의 고장이었다. 밤의 밑바닥이 하얘졌다. 신호소에 기차가 멈췄다.", "터널",
        listOf("국경의 긴 터널을 빠져나오니 눈의 고장이었다.", "나는 고양이로소이다. 이름은 아직 없다.", "읽고 싶은 글을 목소리로 들어요.", "긴 문서도 한 번에 읽어줘요.", "오늘도 좋은 하루 되세요."),
        "1 / 3 페이지", "33%", "제1장 설국",
        listOf("국경의 긴 터널을 빠져나오니 눈의 고장이었다. 밤의 밑이 하얘졌다.", "맞은편 좌석에서 처녀가 일어나 시마무라 앞의 유리창을 내렸다.", "「역장니임, 역장니임.」", "어둠 속에서도 목소리는 맑았다."),
        "국경의 긴 터널을 빠져나오니 눈의 고장이었다.",
        "설정", "음성 설정", "기본 언어", "읽기 속도", "음 높이", "낮음", "높음", "앱 정보", "버전", "지원 언어", "7개 언어"
    ),
    "zh" to SsLoc(
        "语言", "中文", "语速", "慢", "标准 1.0", "快",
        "穿过县境长长的隧道，便是雪国。夜空下一片白茫茫。火车在信号所前停了下来。", "隧道",
        listOf("穿过县境长长的隧道，便是雪国。", "我是猫，还没有名字。", "想读的内容，用声音听。", "再长的文档也能一次读完。", "祝你拥有美好的一天。"),
        "1 / 3 页", "33%", "第一章 雪国",
        listOf("穿过县境长长的隧道，便是雪国。夜空下一片白茫茫。", "对面座位上的姑娘站起来，放下了岛村面前的玻璃窗。", "「站长——，站长——。」", "在黑暗中，声音依然清澈。"),
        "穿过县境长长的隧道，便是雪国。",
        "设置", "语音设置", "默认语言", "朗读速度", "音调", "低", "高", "应用信息", "版本", "支持语言", "7 种语言"
    )
)

@Composable
private fun ScreenshotFlow(initialScreen: Int = 0, lang: String = "ja") {
    var currentScreen by remember { mutableIntStateOf(initialScreen) }
    val interactionSource = remember { MutableInteractionSource() }
    val captions = CAPTIONS[lang] ?: CAPTIONS["ja"]!!
    val subtitles = SUBTITLES[lang]
    val loc = LOC[lang] ?: LOC["ja"]!!
    val navLabels = NAV_LABELS[lang] ?: NAV_LABELS["ja"]!!

    Box(modifier = Modifier.fillMaxSize()) {
        when (currentScreen) {
            0 -> ScreenshotPage(captions[0], subtitles?.get(0), 0, navLabels) { SpeechScreenMock(loc) }
            1 -> ScreenshotPage(captions[1], subtitles?.get(1), 1, navLabels) { HistoryScreenMock(loc) }
            2 -> ScreenshotPage(captions[2], subtitles?.get(2), 2, navLabels) { PdfScreenMock(loc) }
            3 -> ScreenshotPage(captions[3], subtitles?.get(3), 3, navLabels) { SettingsScreenMock(loc) }
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

// 宣材スタイル（iOSと統一）: 淡インディゴ背景 + 大見出し/サブ + スマホ枠
private val SsCanvas = Color(0xFFF2F1FE)   // 淡インディゴ
private val SsAccent = Color(0xFF4B47E0)   // インディゴ
private val SsHeadline = Color(0xFF14132E)
private val SsSubtitle = Color(0xFF5B5D72)

@Composable
private fun ScreenshotPage(
    caption: String,
    subtitle: String?,
    selectedTab: Int,
    navLabels: List<String>,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(SsCanvas)
            .padding(top = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // 見出し
        Text(
            text = caption,
            fontSize = 30.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            lineHeight = 38.sp,
            color = SsHeadline,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp)
        )
        if (subtitle != null) {
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = subtitle,
                fontSize = 15.sp,
                textAlign = TextAlign.Center,
                lineHeight = 21.sp,
                color = SsSubtitle,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp)
            )
        }

        Spacer(modifier = Modifier.height(18.dp))

        // スマホ枠（端末全体が収まる・幅広・上下とも切れない）
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            PhoneFrame(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1080f / 2160f)
            ) {
                Column(modifier = Modifier.fillMaxSize()) {
                    // パンチホール風の上部
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(22.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(9.dp)
                                .clip(CircleShape)
                                .background(Color(0xFF111111))
                        )
                    }
                    Box(modifier = Modifier.weight(1f)) { content() }
                    MockBottomNav(selectedTab = selectedTab, labels = navLabels)
                }
            }
        }
    }
}

@Composable
private fun PhoneFrame(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(40.dp))
            .background(Color.Black)
            .padding(12.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(34.dp))
                .background(Color.White)
        ) {
            content()
        }
    }
}

@Composable
private fun MockBottomNav(selectedTab: Int, labels: List<String>) {
    data class TabItem(val icon: ImageVector, val label: String, val index: Int)

    val tabs = listOf(
        TabItem(Icons.Default.Mic, labels[0], 0),
        TabItem(Icons.Default.History, labels[1], 1),
        TabItem(Icons.Default.PictureAsPdf, labels[2], 2),
        TabItem(Icons.Default.Settings, labels[3], 3)
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
private fun SpeechScreenMock(loc: SsLoc) {
    val sampleText = loc.sampleText
    val highlightWord = loc.highlight

    val annotated = buildAnnotatedString {
        val idx = sampleText.indexOf(highlightWord)
        if (idx >= 0) {
            append(sampleText.substring(0, idx))
            withStyle(
                SpanStyle(
                    background = Color(0xFF4B47E0),
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
                        loc.langLabel,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        loc.langValue,
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
                        loc.speed,
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
                    Text(loc.slow, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(loc.normal, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(loc.fast, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                    containerColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(Icons.Default.Stop, contentDescription = "停止", modifier = Modifier.size(46.dp))
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ---------------------------------------------------------------------------
// Screen 2: History – demo list items
// ---------------------------------------------------------------------------

@Composable
private fun HistoryScreenMock(loc: SsLoc) {
    val items = loc.history

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
private fun PdfScreenMock(loc: SsLoc) {
    val pdfLines = buildList {
        add(loc.pdfTitle)
        add("")
        loc.pdfBody.forEachIndexed { idx, line ->
            add(line)
            if (idx < loc.pdfBody.lastIndex) add("")
        }
    }

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
                    loc.pdfPageLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    loc.pdfPercent,
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
                        val readingText = loc.pdfHighlight
                        val rest = line.removePrefix(readingText)
                        val annotated = buildAnnotatedString {
                            withStyle(
                                SpanStyle(
                                    background = Color(0xFFE3E0FF),
                                    color = Color(0xFF4B47E0)
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
                    containerColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(Icons.Default.Stop, contentDescription = "停止", modifier = Modifier.size(36.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Screen 4: Settings – demo values
// ---------------------------------------------------------------------------

@Composable
private fun SettingsScreenMock(loc: SsLoc) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // TopAppBar mock
        Text(
            text = loc.settings,
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
                        loc.voiceSettings,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )

                    HorizontalDivider()

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(loc.defaultLang, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            loc.langValue,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    HorizontalDivider()

                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(loc.readSpeed, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                "x1.2",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Slider(value = 0.57f, onValueChange = {}, modifier = Modifier.fillMaxWidth())
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(loc.slow, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(loc.normal, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(loc.fast, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    HorizontalDivider()

                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(loc.pitch, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                "x1.0",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        Slider(value = 0.5f, onValueChange = {}, modifier = Modifier.fillMaxWidth())
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(loc.pitchLow, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(loc.normal, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(loc.pitchHigh, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                    Text(loc.appInfo, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    HorizontalDivider()
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(loc.version, style = MaterialTheme.typography.bodyMedium)
                        Text("1.0.0", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    HorizontalDivider()
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(loc.supportedLangs, style = MaterialTheme.typography.bodyMedium)
                        Text(loc.langCount, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}
