package com.entaku.VoiceYourText.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.core.graphics.createBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.Closeable

/**
 * PDF のページを表示用の画像にする。開いたまま保持し、画面に出たページだけを描く
 * （全ページを一度に描くと大きい PDF でメモリが足りなくなるため）。
 *
 * PdfRenderer が描けるのは ARGB_8888 だけ（RGB_565 を渡すと "Unsupported pixel format" で失敗する）。
 * 描いたあと RGB_565 にコピーしてメモリを半分にする（PDF のページは不透明なので見た目は変わらない）。
 * PdfRenderer は同時に1ページしか開けないので Mutex で順番に描く。
 */
class PdfPageRenderer private constructor(
    private val descriptor: ParcelFileDescriptor,
    private val renderer: android.graphics.pdf.PdfRenderer,
) : Closeable {
    private val mutex = Mutex()

    val pageCount: Int get() = renderer.pageCount

    suspend fun render(index: Int, widthPx: Int = DEFAULT_WIDTH_PX): Bitmap = withContext(Dispatchers.IO) {
        mutex.withLock {
            renderer.openPage(index).use { page ->
                val height = (widthPx.toFloat() / page.width * page.height).toInt().coerceAtLeast(1)
                val argb = createBitmap(widthPx, height, Bitmap.Config.ARGB_8888)
                Canvas(argb).drawColor(android.graphics.Color.WHITE)
                page.render(argb, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                argb.copy(Bitmap.Config.RGB_565, false).also { argb.recycle() }
            }
        }
    }

    override fun close() {
        runCatching { renderer.close() }
        runCatching { descriptor.close() }
    }

    companion object {
        const val DEFAULT_WIDTH_PX = 900

        suspend fun open(context: Context, uri: Uri): Result<PdfPageRenderer> = withContext(Dispatchers.IO) {
            runCatching {
                val descriptor = context.contentResolver.openFileDescriptor(uri, "r")
                    ?: error("PDF ファイルを開けませんでした")
                try {
                    PdfPageRenderer(descriptor, android.graphics.pdf.PdfRenderer(descriptor))
                } catch (e: Exception) {
                    descriptor.close()
                    throw e
                }
            }
        }
    }
}
