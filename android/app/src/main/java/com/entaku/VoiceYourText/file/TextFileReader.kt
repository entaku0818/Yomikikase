package com.entaku.VoiceYourText.file

import android.content.Context
import android.net.Uri
import java.io.BufferedReader
import java.io.InputStreamReader

object TextFileReader {
    fun read(context: Context, uri: Uri): Result<String> = runCatching {
        context.contentResolver.openInputStream(uri)?.use { inputStream ->
            BufferedReader(InputStreamReader(inputStream, Charsets.UTF_8)).use { reader ->
                reader.readText()
            }
        } ?: throw IllegalStateException("ファイルを開けませんでした")
    }
}
