package com.entaku.VoiceYourText.aozora

import com.entaku.VoiceYourText.ui.UserMessageException
import com.entaku.VoiceYourText.R
import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.zip.ZipInputStream

/** 作品リストの1件（iOS の AozoraCatalog.json と同じ形） */
data class AozoraWork(
    val id: String,
    val title: String,
    val subtitle: String,
    val author: String,
    val cardUrl: String,
    val textZipUrl: String,
) {
    val displayTitle: String get() = if (subtitle.isBlank()) title else "$title $subtitle"
}

/**
 * 青空文庫の作品を取得する（iOS `AozoraClient` 相当）。
 * 取得するのは図書カードからリンクされている公開テキスト ZIP だけ（スクレイピングはしない）。
 * 作品リストは iOS と同じ `AozoraCatalog.json`（著作権の切れた40作品）を assets に同梱している。
 */
class AozoraClient(
    private val httpClient: OkHttpClient = OkHttpClient.Builder().callTimeout(60, TimeUnit.SECONDS).build(),
) {
    fun loadCatalog(context: Context): List<AozoraWork> {
        val json = context.assets.open(CATALOG_ASSET).bufferedReader().use { it.readText() }
        val works = JSONObject(json).getJSONArray("works")
        return (0 until works.length()).map { i ->
            val w = works.getJSONObject(i)
            AozoraWork(
                id = w.getString("id"),
                title = w.getString("title"),
                subtitle = w.optString("subtitle"),
                author = w.getString("author"),
                cardUrl = w.getString("cardURL"),
                textZipUrl = w.getString("textZipURL"),
            )
        }
    }

    /** 本文をダウンロードし、読み上げ用に整えて、末尾に出典を付けた文字列を返す */
    suspend fun downloadText(work: AozoraWork): String = withContext(Dispatchers.IO) {
        val bytes = try {
            httpClient.newCall(Request.Builder().url(work.textZipUrl).build()).execute().use { response ->
                if (!response.isSuccessful) throw UserMessageException(R.string.aozora_error_server)
                response.body?.bytes() ?: throw UserMessageException(R.string.aozora_error_empty)
            }
        } catch (e: UserMessageException) {
            throw e
        } catch (e: IOException) {
            throw UserMessageException(R.string.aozora_error_offline)
        }
        val raw = AozoraTextNormalizer.decode(extractTxt(bytes))
            ?: throw UserMessageException(R.string.aozora_error_encoding)
        val document = AozoraTextNormalizer.normalize(raw)
        if (document.body.isBlank()) throw UserMessageException(R.string.aozora_error_empty)
        readingText(work, document)
    }

    companion object {
        const val CATALOG_ASSET = "AozoraCatalog.json"

        /** ZIP の中の .txt（無ければ最初のファイル）を取り出す */
        fun extractTxt(zipBytes: ByteArray): ByteArray {
            var fallback: ByteArray? = null
            ZipInputStream(ByteArrayInputStream(zipBytes)).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.isDirectory) continue
                    val data = zip.readBytes()
                    if (entry.name.endsWith(".txt", ignoreCase = true)) return data
                    if (fallback == null) fallback = data
                }
            }
            return fallback ?: throw UserMessageException(R.string.aozora_error_archive)
        }

        /** 本文の前に作品名と著者、末尾に出典（青空文庫・図書カード・底本）を付ける */
        fun readingText(work: AozoraWork, document: AozoraTextNormalizer.Document): String {
            val title = document.title.ifBlank { work.displayTitle }
            val author = document.author.ifBlank { work.author }
            var credit = "出典：青空文庫（${work.cardUrl}）"
            if (document.colophon.isNotBlank()) credit += "\n${document.colophon}"
            return listOf("$title\n$author", document.body, credit).joinToString("\n\n")
        }
    }
}

