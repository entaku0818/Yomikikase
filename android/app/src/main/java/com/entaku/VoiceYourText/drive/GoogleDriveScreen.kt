package com.entaku.VoiceYourText.drive

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.TextSnippet
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.entaku.VoiceYourText.ui.localizedMonthDayFormat
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.Date

private sealed interface DriveUiState {
    data object Checking : DriveUiState
    data object NotConnected : DriveUiState
    data object Loading : DriveUiState
    data class Files(val files: List<DriveFile>) : DriveUiState
    data class Error(val message: Int) : DriveUiState
}

/**
 * Google ドライブのファイル一覧。選んだファイルの本文を onOpen に渡す。
 * 許可（drive.readonly）は Authorization API でもらう。一度許可されていれば画面を開いた時点で一覧を出す。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoogleDriveScreen(
    onOpen: (title: String, text: String) -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val client = remember { GoogleDriveClient() }
    val analytics = remember { AnalyticsClient.get(context) }
    var state by remember { mutableStateOf<DriveUiState>(DriveUiState.Checking) }
    var token by remember { mutableStateOf<String?>(null) }
    var openingId by remember { mutableStateOf<String?>(null) }

    fun loadFiles(accessToken: String) {
        token = accessToken
        state = DriveUiState.Loading
        scope.launch {
            state = try {
                DriveUiState.Files(client.listFiles(accessToken))
            } catch (e: DriveUnauthorizedException) {
                clearToken(context, accessToken)
                DriveUiState.NotConnected
            } catch (e: Exception) {
                Log.w(TAG, "list failed", e)
                DriveUiState.Error(R.string.drive_load_failed)
            }
        }
    }

    val consentLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        val accessToken = runCatching {
            Identity.getAuthorizationClient(context).getAuthorizationResultFromIntent(result.data).accessToken
        }.getOrNull()
        if (result.resultCode == Activity.RESULT_OK && accessToken != null) {
            analytics.logEvent("google_drive_connected", emptyMap())
            loadFiles(accessToken)
        } else {
            state = DriveUiState.NotConnected
        }
    }

    /** interactive=false なら許可画面は出さず、許可済みのときだけ一覧を出す */
    fun authorize(interactive: Boolean) {
        scope.launch {
            val result: AuthorizationResult = try {
                Identity.getAuthorizationClient(context).authorize(
                    AuthorizationRequest.builder().setRequestedScopes(listOf(Scope(GoogleDriveClient.SCOPE))).build()
                ).await()
            } catch (e: Exception) {
                Log.w(TAG, "authorize failed", e)
                state = if (interactive) DriveUiState.Error(R.string.drive_connect_failed) else DriveUiState.NotConnected
                return@launch
            }
            val accessToken = result.accessToken
            val pending = result.pendingIntent
            when {
                !result.hasResolution() && accessToken != null -> loadFiles(accessToken)
                interactive && pending != null ->
                    consentLauncher.launch(IntentSenderRequest.Builder(pending.intentSender).build())
                else -> state = DriveUiState.NotConnected
            }
        }
    }

    LaunchedEffect(Unit) { authorize(interactive = false) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.drive_title)) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                        }
                    }
                )
            }
        ) { padding ->
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                when (val current = state) {
                    DriveUiState.Checking, DriveUiState.Loading ->
                        CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                    DriveUiState.NotConnected -> Message(
                        text = stringResource(R.string.drive_connect_note),
                        button = stringResource(R.string.drive_connect),
                        onClick = { authorize(interactive = true) },
                    )
                    is DriveUiState.Error -> Message(
                        text = stringResource(current.message),
                        button = stringResource(R.string.common_retry),
                        onClick = { token?.let(::loadFiles) ?: authorize(interactive = true) },
                    )
                    is DriveUiState.Files -> if (current.files.isEmpty()) {
                        Message(text = stringResource(R.string.drive_empty), button = null, onClick = {})
                    } else {
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            items(current.files, key = { it.id }) { file ->
                                FileRow(file, isOpening = openingId == file.id) {
                                    val accessToken = token ?: return@FileRow
                                    if (openingId != null) return@FileRow
                                    openingId = file.id
                                    scope.launch {
                                        try {
                                            val text = client.fetchText(accessToken, file)
                                            analytics.logEvent("google_drive_import", mapOf("mime_type" to file.mimeType))
                                            onOpen(GoogleDriveClient.title(file), text)
                                        } catch (e: DriveUnauthorizedException) {
                                            clearToken(context, accessToken)
                                            state = DriveUiState.NotConnected
                                        } catch (e: Exception) {
                                            Log.w(TAG, "fetch failed", e)
                                            state = DriveUiState.Error(R.string.drive_load_failed)
                                        } finally {
                                            openingId = null
                                        }
                                    }
                                }
                                HorizontalDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Message(text: String, button: String?, onClick: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = text, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        if (button != null) {
            Button(onClick = onClick, modifier = Modifier.padding(top = 16.dp)) { Text(button) }
        }
    }
}

@Composable
private fun FileRow(file: DriveFile, isOpening: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (file.isGoogleDoc) Icons.Default.Description else Icons.Default.TextSnippet,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary
        )
        Column(modifier = Modifier.weight(1f).padding(start = 16.dp)) {
            Text(text = file.name, style = MaterialTheme.typography.bodyLarge, maxLines = 2)
            file.modifiedTime?.let {
                Text(
                    text = localizedMonthDayFormat().format(Date.from(it)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        if (isOpening) CircularProgressIndicator(modifier = Modifier.padding(start = 8.dp))
    }
}

/** 期限切れ・取り消し済みのトークンを端末のキャッシュから消す（次の authorize で新しいものをもらう） */
private suspend fun clearToken(context: Context, token: String) = withContext(Dispatchers.IO) {
    runCatching { GoogleAuthUtil.clearToken(context, token) }
}

private const val TAG = "GoogleDrive"
