package com.entaku.VoiceYourText.file

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.FileOpen
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyFilesScreen(
    onOpenFile: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: MyFilesViewModel = viewModel()
) {
    val context = LocalContext.current
    val files by viewModel.filteredFiles.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val filter by viewModel.filter.collectAsState()
    var fileToDelete by remember { mutableStateOf<SavedFileEntity?>(null) }
    var showAddMenu by remember { mutableStateOf(false) }
    var showLinkImport by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    val txtPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            coroutineScope.launch {
                TextFileReader.read(context, it).onSuccess { imported ->
                    viewModel.saveImportedFile(imported.fileName, imported.content, SourceType.TXT_IMPORT)
                    onOpenFile(imported.content)
                }
            }
        }
    }

    Scaffold(
        modifier = modifier,
        floatingActionButton = {
            Box {
                FloatingActionButton(onClick = { showAddMenu = true }) {
                    Icon(Icons.Default.Add, contentDescription = "追加")
                }
                DropdownMenu(expanded = showAddMenu, onDismissRequest = { showAddMenu = false }) {
                    DropdownMenuItem(
                        text = { Text("テキストファイルを開く") },
                        leadingIcon = { Icon(Icons.Default.FileOpen, contentDescription = null) },
                        onClick = {
                            showAddMenu = false
                            txtPickerLauncher.launch("text/*")
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("リンクを追加") },
                        leadingIcon = { Icon(Icons.Default.Link, contentDescription = null) },
                        onClick = {
                            showAddMenu = false
                            showLinkImport = true
                        }
                    )
                }
            }
        }
    ) { paddingValues ->
    Column(modifier = Modifier
        .fillMaxSize()
        .padding(paddingValues)) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = viewModel::setSearchQuery,
            label = { Text("ファイルを検索") },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        )

        SingleChoiceSegmentedButtonRow(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            MyFilesFilter.entries.forEachIndexed { index, entry ->
                SegmentedButton(
                    selected = filter == entry,
                    onClick = { viewModel.setFilter(entry) },
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = MyFilesFilter.entries.size)
                ) {
                    Text(entry.label)
                }
            }
        }

        if (files.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "ファイルがありません",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "テキストを保存するとここに一覧が表示されます",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(files, key = { it.id }) { file ->
                    MyFileItem(
                        file = file,
                        onOpen = { onOpenFile(file.content) },
                        onDelete = { fileToDelete = file }
                    )
                }
            }
        }
    }

    fileToDelete?.let { file ->
        AlertDialog(
            onDismissRequest = { fileToDelete = null },
            title = { Text("削除の確認") },
            text = { Text("「${file.title}」を削除しますか？") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(file.id)
                    fileToDelete = null
                }) {
                    Text("削除")
                }
            },
            dismissButton = {
                TextButton(onClick = { fileToDelete = null }) {
                    Text("キャンセル")
                }
            }
        )
    }

    if (showLinkImport) {
        LinkImportScreen(
            onDismiss = { showLinkImport = false },
            onTextExtracted = { title, text ->
                viewModel.saveImportedFile(title, text, SourceType.LINK)
                showLinkImport = false
                onOpenFile(text)
            }
        )
    }
    }
}

private val MyFilesFilter.label: String
    get() = when (this) {
        MyFilesFilter.ALL -> "すべて"
        MyFilesFilter.TEXT -> "テキスト"
        MyFilesFilter.LINK -> "リンク"
    }

@Composable
private fun MyFileItem(
    file: SavedFileEntity,
    onOpen: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        onClick = onOpen,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        ),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (file.sourceType == SourceType.LINK) Icons.Default.Link else Icons.Default.Description,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 12.dp)
            ) {
                Text(
                    text = file.title,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = formatDate(file.updatedAt),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            IconButton(onClick = onOpen) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = "再生",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "削除",
                    tint = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

private fun formatDate(epochMillis: Long): String {
    val target = Calendar.getInstance().apply { timeInMillis = epochMillis }
    val today = Calendar.getInstance()
    val isToday = target.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
        target.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
    return if (isToday) {
        "今日"
    } else {
        SimpleDateFormat("M月d日", Locale.getDefault()).format(target.time)
    }
}
