package com.entaku.VoiceYourText.file

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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** ゴミ箱（iOS `Features/DeletedItems/` 相当）。7日間は元に戻せ、すぐに完全削除もできる */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrashScreen(
    files: List<SavedFileEntity>,
    onRestore: (String) -> Unit,
    onDeletePermanently: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var toDelete by remember { mutableStateOf<SavedFileEntity?>(null) }
    val now = System.currentTimeMillis()
    val dateFormat = remember { SimpleDateFormat("M月d日", Locale.JAPAN) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("ゴミ箱") },
                    navigationIcon = { IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, contentDescription = "閉じる") } }
                )
            }
        ) { padding ->
            if (files.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("削除済みのファイルはありません", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            "削除したファイルは${TRASH_RETENTION_DAYS}日間保持されます",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize().padding(padding)) {
                    items(files, key = { it.id }) { file ->
                        val deletedAt = file.deletedAt ?: now
                        val days = trashDaysRemaining(deletedAt, now)
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(file.title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    "${dateFormat.format(Date(deletedAt))}に削除・あと${days}日",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = if (days <= 1) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            TextButton(onClick = { onRestore(file.id) }) { Text("元に戻す") }
                            TextButton(onClick = { toDelete = file }) { Text("削除", color = MaterialTheme.colorScheme.error) }
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }

    toDelete?.let { file ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text("完全に削除") },
            text = { Text("「${file.title}」を完全に削除しますか？元に戻せません。") },
            confirmButton = {
                TextButton(onClick = {
                    onDeletePermanently(file.id)
                    toDelete = null
                }) { Text("削除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text("キャンセル") } }
        )
    }
}
