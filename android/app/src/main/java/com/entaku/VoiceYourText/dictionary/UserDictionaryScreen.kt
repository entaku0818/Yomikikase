package com.entaku.VoiceYourText.dictionary

import com.entaku.VoiceYourText.R
import androidx.compose.ui.res.stringResource
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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties

/** ユーザー辞書（iOS `UserDictionaryView` 相当）。登録した単語は読み上げ時に読み方へ置き換える */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserDictionaryScreen(onDismiss: () -> Unit) {
    val store = UserDictionaryStore.get(LocalContext.current)
    val entries by store.entries.collectAsState()
    var showAdd by remember { mutableStateOf(false) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.dictionary_title)) },
                    navigationIcon = { IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, contentDescription = stringResource(R.string.common_close)) } }
                )
            },
            floatingActionButton = {
                FloatingActionButton(onClick = { showAdd = true }) { Icon(Icons.Default.Add, contentDescription = stringResource(R.string.common_add)) }
            }
        ) { padding ->
            if (entries.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(24.dp)) {
                        Text(stringResource(R.string.dictionary_empty), style = MaterialTheme.typography.bodyLarge)
                        Text(
                            stringResource(R.string.dictionary_empty_hint),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize().padding(padding)) {
                    items(entries.sortedByDescending { it.createdAt }, key = { it.id }) { entry ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(entry.word, style = MaterialTheme.typography.bodyLarge)
                                Text(entry.reading, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            IconButton(onClick = { store.delete(entry.id) }) {
                                Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.common_delete), tint = MaterialTheme.colorScheme.error)
                            }
                        }
                        HorizontalDivider()
                    }
                }
            }
        }

        if (showAdd) {
            var word by remember { mutableStateOf("") }
            var reading by remember { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = { showAdd = false },
                title = { Text(stringResource(R.string.dictionary_add_title)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(value = word, onValueChange = { word = it }, label = { Text(stringResource(R.string.dictionary_word)) }, singleLine = true)
                        OutlinedTextField(value = reading, onValueChange = { reading = it }, label = { Text(stringResource(R.string.dictionary_reading)) }, singleLine = true)
                    }
                },
                confirmButton = {
                    TextButton(
                        onClick = {
                            store.add(word, reading)
                            showAdd = false
                        },
                        enabled = word.isNotBlank() && reading.isNotBlank()
                    ) { Text(stringResource(R.string.common_add)) }
                },
                dismissButton = { TextButton(onClick = { showAdd = false }) { Text(stringResource(R.string.common_cancel)) } }
            )
        }
    }
}
