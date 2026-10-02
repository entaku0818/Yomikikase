package com.entaku.VoiceYourText.scan

import android.app.Activity
import android.content.Context
import android.content.IntentSender
import android.net.Uri
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * スキャン（カメラで撮って文字認識）。iOS `Features/DocumentScanner/` 相当。
 * - 撮影・切り抜き・傾き補正は ML Kit Document Scanner（ギャラリーからの読み込みも可）
 * - 文字認識は ML Kit Text Recognition（日本語。英数字も読める）
 * スキャナは Google Play 開発者サービス経由（使えない端末では写真を選ぶ方式に切り替える）。
 * 文字認識のモデルはアプリに同梱する（開発者サービス経由だと初回利用時にダウンロード待ちで失敗するため）。
 */
object ScanTextRecognizer {

    /** スキャナを開く IntentSender を取得する */
    suspend fun startIntent(activity: Activity): IntentSender {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(MAX_PAGES)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        return GmsDocumentScanning.getClient(options).getStartScanIntent(activity).await()
    }

    /** スキャンしたページの画像から文字を取り出し、ページ順につなげる */
    suspend fun recognize(context: Context, pages: List<Uri>): String {
        val recognizer = TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
        try {
            return joinPages(pages.map { uri ->
                val result = recognizer.process(InputImage.fromFilePath(context, uri)).await()
                result.textBlocks.joinToString("\n") { block -> block.lines.joinToString("\n") { it.text } }
            })
        } finally {
            recognizer.close()
        }
    }

    /** 空のページを除き、ページの間は空行で区切る */
    fun joinPages(pages: List<String>): String = pages.map { it.trim() }.filter { it.isNotEmpty() }.joinToString("\n\n")

    const val MAX_PAGES = 20
}

private suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { cont ->
    addOnSuccessListener { cont.resume(it) }
    addOnFailureListener { cont.resumeWithException(it) }
    addOnCanceledListener { cont.cancel() }
}
