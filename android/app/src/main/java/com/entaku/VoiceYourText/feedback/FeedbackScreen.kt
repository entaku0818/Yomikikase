package com.entaku.VoiceYourText.feedback

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.launch

/** フィードバック入力画面（全画面ダイアログ）。iOS `FeedbackView` と同じ文言。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedbackDialog(
    onDismiss: () -> Unit,
    client: FeedbackClient = remember { FeedbackClient() },
) {
    var message by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var submitted by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("フィードバック") },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, contentDescription = "キャンセル") }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "ご不便をおかけして申し訳ありません。\n改善のため、詳しく教えていただけますか？",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                OutlinedTextField(
                    value = message,
                    onValueChange = { message = it.take(FeedbackClient.MAX_LENGTH) },
                    placeholder = { Text("不満な点や改善してほしいことを入力してください") },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp)
                )
                if (failed) {
                    Text(
                        text = "送信できませんでした。通信状況を確認してもう一度お試しください。",
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
                Button(
                    onClick = {
                        isSubmitting = true
                        failed = false
                        scope.launch {
                            runCatching { client.submit(message) }
                                .onSuccess { submitted = true }
                                .onFailure { failed = true }
                            isSubmitting = false
                        }
                    },
                    enabled = message.isNotBlank() && !isSubmitting,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    if (isSubmitting) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Text("送信する")
                    }
                }
            }
        }
    }

    if (submitted) {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("送信完了") },
            text = { Text("フィードバックをありがとうございます。今後の改善に役立てます。") },
            confirmButton = { TextButton(onClick = onDismiss) { Text("OK") } }
        )
    }
}
