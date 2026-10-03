package com.entaku.VoiceYourText.aozora

import com.entaku.VoiceYourText.ui.userMessage
import com.entaku.VoiceYourText.R
import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import kotlinx.coroutines.launch

/**
 * 名作（青空文庫）の作品一覧（iOS `AozoraLibraryView.swift` 相当）。
 * 作品を選ぶと本文をダウンロードして onOpen に渡す。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AozoraLibraryScreen(
    onOpen: (work: AozoraWork, text: String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    client: AozoraClient = remember { AozoraClient() },
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val analytics = remember { AnalyticsClient.get(context) }
    val works = remember { runCatching { client.loadCatalog(context) }.getOrDefault(emptyList()) }
    var query by remember { mutableStateOf("") }
    var downloading by remember { mutableStateOf<AozoraWork?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    val filtered = works.filter {
        query.isBlank() || it.title.contains(query, ignoreCase = true) || it.author.contains(query, ignoreCase = true)
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.aozora_title), fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back)) }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                placeholder = { Text(stringResource(R.string.aozora_search)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            )
            Text(
                text = stringResource(R.string.aozora_intro),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(filtered, key = { it.id }) { work ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(enabled = downloading == null) {
                                downloading = work
                                analytics.logEvent("aozora_download_started", mapOf("work_id" to work.id))
                                scope.launch {
                                    runCatching { client.downloadText(work) }
                                        .onSuccess { text ->
                                            analytics.logEvent("aozora_download_completed", mapOf("work_id" to work.id))
                                            onOpen(work, text)
                                        }
                                        .onFailure {
                                            analytics.logEvent("aozora_download_failed", mapOf("work_id" to work.id))
                                            error = it.userMessage(context, R.string.aozora_failed_title)
                                        }
                                    downloading = null
                                }
                            }
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                    ) {
                        Text(work.displayTitle, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                        Text(work.author, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    HorizontalDivider()
                }
            }
        }
    }

    downloading?.let { work ->
        AlertDialog(
            onDismissRequest = {},
            title = { Text(stringResource(R.string.aozora_downloading_title)) },
            text = {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxWidth()) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator()
                        Text(stringResource(R.string.aozora_downloading, work.title), modifier = Modifier.padding(top = 12.dp))
                    }
                }
            },
            confirmButton = {}
        )
    }

    error?.let { message ->
        AlertDialog(
            onDismissRequest = { error = null },
            title = { Text(stringResource(R.string.aozora_failed_title)) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { error = null }) { Text(stringResource(R.string.common_ok)) } }
        )
    }
}
