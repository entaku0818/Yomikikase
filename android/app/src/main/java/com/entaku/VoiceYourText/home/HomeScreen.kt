package com.entaku.VoiceYourText.home

import com.entaku.VoiceYourText.ui.userMessage
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.drive.GoogleDriveScreen
import androidx.compose.material.icons.filled.AddToDrive
import androidx.compose.ui.res.stringResource
import android.net.Uri
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.entaku.VoiceYourText.scan.ScanTextRecognizer
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.activity.result.IntentSenderRequest
import android.content.ContextWrapper
import android.content.Context
import android.app.Activity
import androidx.compose.material.icons.filled.AutoStories
import com.entaku.VoiceYourText.pdf.PdfTextReader
import com.entaku.VoiceYourText.epub.EpubTextExtractor
import androidx.compose.material3.TextButton
import androidx.compose.material3.AlertDialog
import androidx.compose.material.icons.automirrored.filled.MenuBook
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
    onOpenAozora: () -> Unit,
    onSaveImported: (title: String, content: String, sourceType: SourceType) -> Unit,
    modifier: Modifier = Modifier,
    extraActions: List<HomeAction> = emptyList(),
    /** 新しいファイルを増やす操作の前に呼ぶ。無料版の上限に達していれば block を実行せずに案内を出す */
    guardNewFile: (block: () -> Unit) -> Unit = { it() },
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val analytics = remember { AnalyticsClient.get(context) }
    var showLinkImport by remember { mutableStateOf(false) }
    var showDrive by remember { mutableStateOf(false) }
    var importError by remember { mutableStateOf<String?>(null) }

    val txtPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            TextFileReader.read(context, uri).onSuccess { imported ->
                onSaveImported(imported.fileName, imported.content, SourceType.TXT_IMPORT)
                onOpenText(imported.content)
            }
        }
    }

    val epubPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            EpubTextExtractor.read(context, uri)
                .onSuccess { book ->
                    val title = book.title ?: PdfTextReader.displayName(context, uri) ?: context.getString(R.string.home_book_default_title)
                    onSaveImported(title, book.text, SourceType.EPUB)
                    onOpenText(book.text)
                }
                .onFailure { importError = it.userMessage(context, R.string.common_load_failed_title) }
        }
    }

    // スキャン: Document Scanner で撮影 → 文字認識 → テキスト画面で開く
    var isRecognizing by remember { mutableStateOf(false) }
    fun recognizePages(pages: List<Uri>) {
        isRecognizing = true
        scope.launch {
            runCatching { ScanTextRecognizer.recognize(context, pages) }
                .onSuccess { text ->
                    if (text.isBlank()) {
                        importError = context.getString(R.string.scan_no_text)
                    } else {
                        analytics.logEvent("scan_completed", mapOf("pages" to pages.size, "length" to text.length))
                        onSaveImported(text.lineSequence().first().take(30), text, SourceType.SCAN)
                        onOpenText(text)
                    }
                }
                .onFailure {
                    analytics.logEvent("scan_error", mapOf("reason" to (it.message ?: "unknown").take(100)))
                    importError = context.getString(R.string.scan_failed, it.message.orEmpty())
                }
            isRecognizing = false
        }
    }
    val scanner = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        val pages = GmsDocumentScanningResult.fromActivityResultIntent(result.data)?.pages?.map { it.imageUri }
        if (result.resultCode == Activity.RESULT_OK && !pages.isNullOrEmpty()) recognizePages(pages)
    }
    // Document Scanner が使えない端末（Google Play 開発者サービスが古いなど）は、写真を選んで文字認識する
    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris ->
        if (uris.isNotEmpty()) recognizePages(uris.take(ScanTextRecognizer.MAX_PAGES))
    }

    val actions = listOf(
        HomeAction("text", stringResource(R.string.home_text), Icons.Default.Description) { onOpenText("") },
        HomeAction("pdf", stringResource(R.string.home_pdf), Icons.Default.PictureAsPdf, onOpenPdf),
        HomeAction("txt", stringResource(R.string.home_txt), Icons.Default.TextSnippet) { txtPicker.launch("text/*") },
        HomeAction("epub", stringResource(R.string.home_book), Icons.AutoMirrored.Filled.MenuBook) { epubPicker.launch("application/epub+zip") },
        HomeAction("link", stringResource(R.string.home_link), Icons.Default.Link) { showLinkImport = true },
        HomeAction("scan", stringResource(R.string.home_scan), Icons.Default.DocumentScanner) {
            val activity = context.findActivity() ?: return@HomeAction
            scope.launch {
                runCatching { ScanTextRecognizer.startIntent(activity) }
                    .onSuccess { scanner.launch(IntentSenderRequest.Builder(it).build()) }
                    .onFailure {
                        analytics.logEvent("scan_error", mapOf("reason" to "scanner_unavailable"))
                        imagePicker.launch("image/*")
                    }
            }
        },
        HomeAction("aozora", stringResource(R.string.home_aozora), Icons.Default.AutoStories, onOpenAozora),
        HomeAction("google_drive", stringResource(R.string.drive_title), Icons.Default.AddToDrive) { showDrive = true },
    ).map { action -> action.copy(onClick = { guardNewFile(action.onClick) }) } + extraActions

    Column(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 8.dp)) {
            Text(text = stringResource(R.string.home_title), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Text(
                text = stringResource(R.string.home_subtitle),
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

    if (isRecognizing) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text(stringResource(R.string.home_recognizing)) },
            text = { CircularProgressIndicator() },
            confirmButton = {}
        )
    }

    importError?.let { message ->
        AlertDialog(
            onDismissRequest = { importError = null },
            title = { Text(stringResource(R.string.common_load_failed_title)) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { importError = null }) { Text(stringResource(R.string.common_ok)) } }
        )
    }

    if (showDrive) {
        GoogleDriveScreen(
            onDismiss = { showDrive = false },
            onOpen = { title, text ->
                onSaveImported(title, text, SourceType.TXT_IMPORT)
                showDrive = false
                onOpenText(text)
            }
        )
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

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
