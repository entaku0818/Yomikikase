package com.entaku.VoiceYourText.file

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.BufferedReader
import java.io.InputStreamReader

data class ImportedText(val fileName: String, val content: String)

object TextFileReader {
    fun read(context: Context, uri: Uri): Result<ImportedText> = runCatching {
        val content = context.contentResolver.openInputStream(uri)?.use { inputStream ->
            BufferedReader(InputStreamReader(inputStream, Charsets.UTF_8)).use { reader ->
                reader.readText()
            }
        } ?: throw IllegalStateException("ファイルを開けませんでした")
        ImportedText(fileName = resolveFileName(context, uri), content = content)
    }

    private fun resolveFileName(context: Context, uri: Uri): String {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                cursor.getString(nameIndex)?.let { return it }
            }
        }
        return "テキストファイル"
    }
}
