package com.entaku.VoiceYourText.home

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.TextSnippet
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.entaku.VoiceYourText.file.LinkImportScreen
import com.entaku.VoiceYourText.file.SourceType
import com.entaku.VoiceYourText.file.TextFileReader
import kotlinx.coroutines.launch

/** ホームに並べる取り込み元1つ分 */
data class HomeAction(val key: String, val title: String, val icon: ImageVector, val onClick: () -> Unit)

/**
 * ホーム画面（iOS `HomeView.swift` 相当）。取り込み元のボタンを2列で並べる。
 * 実装済みの取り込み元だけを出し、EPUB・名作・スキャンは実装に合わせて増やす（#141〜#143）。
 *
 * @param onOpenText 取り込んだ文章を読み上げ画面で開く
 * @param onSaveImported 取り込んだ文章をマイファイルに保存する
 */
@Composable
fun HomeScreen(
    onOpenText: (String) -> Unit,
    onOpenPdf: () -> Unit,
    onSaveImported: (title: String, content: String, sourceType: SourceType) -> Unit,
    modifier: Modifier = Modifier,
    extraActions: List<HomeAction> = emptyList(),
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val analytics = remember { AnalyticsClient.get(context) }
    var showLinkImport by remember { mutableStateOf(false) }

    val txtPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            TextFileReader.read(context, uri).onSuccess { imported ->
                onSaveImported(imported.fileName, imported.content, SourceType.TXT_IMPORT)
                onOpenText(imported.content)
            }
        }
    }

    val actions = listOf(
        HomeAction("text", "テキスト", Icons.Default.Description) { onOpenText("") },
        HomeAction("pdf", "PDF", Icons.Default.PictureAsPdf, onOpenPdf),
        HomeAction("txt", "TXTファイル", Icons.Default.TextSnippet) { txtPicker.launch("text/*") },
        HomeAction("link", "リンク", Icons.Default.Link) { showLinkImport = true },
    ) + extraActions

    Column(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 8.dp)) {
            Text(text = "ナレーター", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Text(
                text = "読みたいものを、声で。",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(actions, key = { it.key }) { action ->
                HomeButton(action) {
                    analytics.logEvent("home_button_tapped", mapOf("button" to action.key))
                    action.onClick()
                }
            }
        }
    }

    if (showLinkImport) {
        LinkImportScreen(
            onDismiss = { showLinkImport = false },
            onTextExtracted = { title, text ->
                onSaveImported(title, text, SourceType.LINK)
                showLinkImport = false
                onOpenText(text)
            }
        )
    }
}

@Composable
private fun HomeButton(action: HomeAction, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = Modifier.fillMaxWidth().aspectRatio(1.3f)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = action.icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(40.dp)
                )
            }
            Text(
                text = action.title,
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.padding(top = 12.dp)
            )
        }
    }
}
