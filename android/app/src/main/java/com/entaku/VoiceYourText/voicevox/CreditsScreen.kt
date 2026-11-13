package com.entaku.VoiceYourText.voicevox

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.TextButton
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.entaku.VoiceYourText.R

/** クレジット。キャラ音声（VOICEVOX）は各キャラの利用規約で、アプリ内の分かる場所への表記が求められている */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreditsScreen(onDismiss: () -> Unit) {
    val uriHandler = LocalUriHandler.current
    val context = LocalContext.current
    val client = remember { VoicevoxClient(catalogCache = VoicevoxCatalogCache(context)) }
    var catalog by remember { mutableStateOf(client.cachedCatalog()) }
    var loading by remember { mutableStateOf(true) }
    var failed by remember { mutableStateOf(false) }
    var reload by remember { mutableStateOf(0) }
    LaunchedEffect(reload) {
        loading = true
        failed = false
        try { catalog = client.catalog() }
        catch (e: kotlinx.coroutines.CancellationException) { throw e }
        catch (_: Exception) { failed = true }
        finally { loading = false }
    }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.credits_title)) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                        }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
            ) {
                Text(
                    text = stringResource(R.string.voicevox_section_title),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 4.dp)
                )
                LinkRow("Kokoro-82M · Apache 2.0") {
                    runCatching { uriHandler.openUri("https://huggingface.co/hexgrad/Kokoro-82M") }
                }
                LinkRow("ONNX Runtime · MIT / Kuromoji · Apache 2.0") {
                    runCatching { uriHandler.openUri("https://onnxruntime.ai/") }
                }
                if (loading && catalog == null) CircularProgressIndicator(modifier = Modifier.padding(16.dp))
                if (failed) TextButton(onClick = { reload++ }) { Text(stringResource(R.string.common_retry)) }
                catalog?.credits.orEmpty().forEach { voice ->
                    LinkRow(voice.credit) { runCatching { uriHandler.openUri(voice.termsUrl) } }
                }
                Text(
                    text = stringResource(R.string.credits_voicevox_note),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp)
                )
                HorizontalDivider()
                catalog?.termsUrl?.let { terms ->
                    LinkRow(stringResource(R.string.credits_voicevox_terms)) { runCatching { uriHandler.openUri(terms) } }
                }
            }
        }
    }
}

@Composable
private fun LinkRow(text: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = text, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Icon(
            Icons.AutoMirrored.Filled.OpenInNew,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
