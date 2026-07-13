package com.entaku.VoiceYourText.file

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LinkImportScreen(
    onDismiss: () -> Unit,
    onTextExtracted: (title: String, text: String) -> Unit
) {
    var urlText by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val isValidUrl = urlText.startsWith("https://") && urlText.length > 12

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("リンク") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "WebページのURLを入力すると、テキストを抽出して読み上げます。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                OutlinedTextField(
                    value = urlText,
                    onValueChange = { urlText = it },
                    label = { Text("URL") },
                    placeholder = { Text("https://example.com") },
                    singleLine = true,
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth()
                )
                errorMessage?.let { message ->
                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                        Text(
                            text = message,
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(start = 8.dp)
                        )
                    }
                }
                if (isLoading) {
                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.padding(end = 8.dp))
                        Text("取得中…")
                    }
                }
            }
        },
        confirmButton = {
            Button(
                enabled = isValidUrl && !isLoading,
                onClick = {
                    errorMessage = null
                    isLoading = true
                    scope.launch {
                        WebPageFetcher.fetchText(urlText)
                            .onSuccess { page ->
                                isLoading = false
                                if (page.text.isBlank()) {
                                    errorMessage = "テキストを取得できませんでした"
                                } else {
                                    onTextExtracted(page.title, page.text)
                                }
                            }
                            .onFailure { error ->
                                isLoading = false
                                errorMessage = error.message ?: "テキストを取得できませんでした"
                            }
                    }
                }
            ) {
                Text("テキストを取得")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("閉じる")
            }
        }
    )
}
