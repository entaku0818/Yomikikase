package com.entaku.VoiceYourText.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class PdfPage(
    val pageIndex: Int,
    val bitmap: Bitmap
)

object PdfRenderer {

    /**
     * Renders all pages of a PDF as bitmaps.
     * Uses Android's built-in PdfRenderer (API 21+, no external libs).
     */
    suspend fun renderPages(
        context: Context,
        uri: Uri,
        widthPx: Int = 1080
    ): Result<List<PdfPage>> = withContext(Dispatchers.IO) {
        runCatching {
            val pfd: ParcelFileDescriptor = context.contentResolver.openFileDescriptor(uri, "r")
                ?: error("PDF ファイルを開けませんでした")

            pfd.use { descriptor ->
                val renderer = android.graphics.pdf.PdfRenderer(descriptor)
                renderer.use { pdf ->
                    (0 until pdf.pageCount).map { index ->
                        pdf.openPage(index).use { page ->
                            val height = (widthPx.toFloat() / page.width * page.height).toInt()
                            val bitmap = Bitmap.createBitmap(widthPx, height, Bitmap.Config.ARGB_8888)
                            // Fill with white background
                            Canvas(bitmap).drawColor(android.graphics.Color.WHITE)
                            page.render(bitmap, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            PdfPage(index, bitmap)
                        }
                    }
                }
            }
        }
    }

    fun getPageCount(context: Context, uri: Uri): Int {
        return runCatching {
            context.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                android.graphics.pdf.PdfRenderer(pfd).use { it.pageCount }
            } ?: 0
        }.getOrDefault(0)
    }
}
