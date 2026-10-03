package com.entaku.VoiceYourText.pdf

import com.entaku.VoiceYourText.ui.UserMessageException
import com.entaku.VoiceYourText.R
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import java.io.StringWriter
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

    /**
     * ページ順に結合した本文と、各文字のページ上の位置。ページの間は空行で区切る。
     * 位置は PDFTextStripper が文字列を書き出すときの TextPosition から取る。
     */
    suspend fun readLayout(context: Context, uri: Uri): Result<PdfTextLayout> =
        withContext(Dispatchers.IO) {
            runCatching {
                PDFBoxResourceLoader.init(context.applicationContext)
                val input = context.contentResolver.openInputStream(uri) ?: throw UserMessageException(R.string.error_open_file)
                input.use { stream ->
                    PDDocument.load(stream).use { document ->
                        val raw = StringBuilder()
                        val glyphs = mutableListOf<PdfGlyph>()
                        for (pageIndex in 0 until document.numberOfPages) {
                            val page = document.getPage(pageIndex)
                            val width = page.mediaBox.width.takeIf { it > 0 } ?: 1f
                            val height = page.mediaBox.height.takeIf { it > 0 } ?: 1f
                            val writer = StringWriter()
                            val pageStart = raw.length
                            val stripper = object : PDFTextStripper() {
                                override fun writeString(text: String, textPositions: List<TextPosition>) {
                                    val base = pageStart + writer.buffer.length
                                    textPositions.forEachIndexed { i, pos ->
                                        if (i < text.length) {
                                            glyphs += PdfGlyph(
                                                offset = base + i,
                                                page = pageIndex,
                                                x = (pos.xDirAdj + pos.widthDirAdj / 2) / width,
                                                y = (pos.yDirAdj - pos.heightDir / 2) / height,
                                            )
                                        }
                                    }
                                    super.writeString(text, textPositions)
                                }
                            }.apply {
                                startPage = pageIndex + 1
                                endPage = pageIndex + 1
                            }
                            stripper.writeText(document, writer)
                            raw.append(writer.buffer)
                            if (pageIndex < document.numberOfPages - 1) raw.append("\n\n")
                        }
                        PdfTextLayout(raw.toString(), glyphs)
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
