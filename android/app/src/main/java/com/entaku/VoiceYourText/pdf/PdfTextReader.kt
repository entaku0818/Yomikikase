package com.entaku.VoiceYourText.pdf

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * PDF から読み上げ用の文字を取り出す。
 *
 * Android 標準の PdfRenderer は画像化しかできず、文字の取得（Page.getTextContents）は API 35 以降のみ。
 * minSdk 30 でも動くよう PdfBox-Android（Apache License 2.0）を使う。
 * 画像だけの PDF（スキャン）は空文字になる（文字認識は #143 スキャンで対応）。
 */
object PdfTextReader {

    /** ページ順に結合した本文。ページの間は空行で区切る */
    suspend fun read(context: Context, uri: Uri, maxPages: Int = Int.MAX_VALUE): Result<String> =
        withContext(Dispatchers.IO) {
            runCatching {
                PDFBoxResourceLoader.init(context.applicationContext)
                val input = context.contentResolver.openInputStream(uri) ?: error("PDF ファイルを開けませんでした")
                input.use { stream ->
                    PDDocument.load(stream).use { document ->
                        val stripper = PDFTextStripper().apply {
                            startPage = 1
                            endPage = minOf(document.numberOfPages, maxPages)
                        }
                        clean(stripper.getText(document))
                    }
                }
            }
        }

    /** 行末の空白（PDF のレイアウト由来）を落とし、改行コードを揃える */
    fun clean(text: String): String =
        text.replace("\r\n", "\n")
            .lines()
            .joinToString("\n") { it.trimEnd() }
            .trim()

    /** 端末上のファイル名（拡張子なし）。マイファイルのタイトルに使う */
    fun displayName(context: Context, uri: Uri): String? =
        runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0)?.substringBeforeLast('.') else null
            }
        }.getOrNull()
}
