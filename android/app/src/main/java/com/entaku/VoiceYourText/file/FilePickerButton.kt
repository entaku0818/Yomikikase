package com.entaku.VoiceYourText.file

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FileOpen
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
fun FilePickerButton(
    onFilePicked: (Uri) -> Unit,
    modifier: Modifier = Modifier
) {
    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let { onFilePicked(it) }
    }

    IconButton(
        onClick = { launcher.launch("text/*") },
        modifier = modifier
    ) {
        Icon(
            imageVector = Icons.Default.FileOpen,
            contentDescription = "テキストファイルを開く",
            tint = MaterialTheme.colorScheme.primary
        )
    }
}
