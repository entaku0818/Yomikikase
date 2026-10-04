package com.entaku.VoiceYourText.drive

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.activity.result.contract.ActivityResultContract
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.file.SourceType
import com.entaku.VoiceYourText.file.TextFileReader
import com.entaku.VoiceYourText.pdf.PdfTextReader
import com.entaku.VoiceYourText.ui.UserMessageException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

data class CloudImport(val title: String, val text: String, val sourceType: SourceType)

/**
 * Google ドライブなどのファイルを OS のファイル選択画面から取り込む。
 *
 * ドライブ全体を読む OAuth 権限（drive.readonly）は Google の審査が要るので使わず、
 * 利用者が選んだファイルだけを受け取る。ドライブアプリが入っていれば選択画面に「ドライブ」が出る。
 * Google ドキュメントは中身のない「仮想ファイル」なので、ドライブが用意している形式（テキスト／PDF）に書き出して読む。
 */
object CloudFileImporter {
    const val GOOGLE_DOC = "application/vnd.google-apps.document"

    /** 選択画面で選べる種類 */
    val MIME_TYPES = arrayOf("text/plain", "text/markdown", "text/x-markdown", "application/pdf", GOOGLE_DOC)

    /** 仮想ファイルの書き出し形式を選ぶ（テキストを優先、無ければ PDF）。どちらも無ければ null */
    fun exportType(streamTypes: List<String>): String? =
        streamTypes.firstOrNull { it.startsWith("text/plain") }
            ?: streamTypes.firstOrNull { it.startsWith("text/") }
            ?: streamTypes.firstOrNull { it == "application/pdf" }

    suspend fun import(context: Context, uri: Uri): Result<CloudImport> = withContext(Dispatchers.IO) {
        runCatching {
            val resolver = context.contentResolver
            val title = PdfTextReader.displayName(context, uri) ?: context.getString(R.string.default_text_file_name)
            if (isVirtual(context, uri)) {
                val streamTypes = resolver.getStreamTypes(uri, "*/*")?.toList().orEmpty()
                val type = exportType(streamTypes) ?: throw UserMessageException(R.string.drive_unsupported)
                // 書き出した中身を一時ファイルに落としてから、通常のファイルと同じ方法で読む
                val temp = File.createTempFile("cloud", if (type == "application/pdf") ".pdf" else ".txt", context.cacheDir)
                try {
                    resolver.openTypedAssetFileDescriptor(uri, type, null)?.createInputStream()?.use { input ->
                        temp.outputStream().use { input.copyTo(it) }
                    } ?: throw UserMessageException(R.string.error_open_file)
                    read(context, Uri.fromFile(temp), type, title)
                } finally {
                    temp.delete()
                }
            } else {
                read(context, uri, resolver.getType(uri).orEmpty(), title)
            }
        }
    }

    private suspend fun read(context: Context, uri: Uri, type: String, title: String): CloudImport =
        if (type == "application/pdf") {
            val text = PdfTextReader.readLayout(context, uri).getOrThrow().text
            if (text.isBlank()) throw UserMessageException(R.string.drive_unsupported)
            CloudImport(title, text, SourceType.PDF)
        } else {
            val text = TextFileReader.read(context, uri).getOrThrow().content.removePrefix(BOM)
            CloudImport(title, text, SourceType.TXT_IMPORT)
        }

    private fun isVirtual(context: Context, uri: Uri): Boolean {
        if (!DocumentsContract.isDocumentUri(context, uri)) return false
        return runCatching {
            context.contentResolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_FLAGS), null, null, null)?.use { cursor ->
                cursor.moveToFirst() && (cursor.getInt(0) and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT) != 0
            } ?: false
        }.getOrDefault(false)
    }

    private val BOM = Char(0xFEFF).toString()
}

/**
 * ファイル選択画面を開く。仮想ファイル（Google ドキュメント）も選べるよう CATEGORY_OPENABLE を付けない
 * （ActivityResultContracts.OpenDocument は付けてしまう）。
 */
class OpenCloudDocument : ActivityResultContract<Array<String>, Uri?>() {
    override fun createIntent(context: Context, input: Array<String>): Intent =
        Intent(Intent.ACTION_OPEN_DOCUMENT)
            .setType("*/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, input)

    override fun parseResult(resultCode: Int, intent: Intent?): Uri? = intent?.data
}
