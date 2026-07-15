package com.entaku.VoiceYourText.file

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.jsoup.Jsoup
import java.util.concurrent.TimeUnit

data class FetchedPage(val title: String, val text: String)

object WebPageFetcher {
    private val defaultClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    suspend fun fetchText(url: String, client: OkHttpClient = defaultClient): Result<FetchedPage> = withContext(Dispatchers.IO) {
        runCatching {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", "Mozilla/5.0 (compatible; VoiceYourText/1.0)")
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw IllegalStateException("ページの取得に失敗しました (HTTP ${response.code})")
                }
                val html = response.body?.string() ?: throw IllegalStateException("ページの内容を取得できませんでした")
                val doc = Jsoup.parse(html, url)
                val title = doc.title().ifBlank { doc.location() }
                val text = doc.body()?.text().orEmpty()
                FetchedPage(title = title, text = text)
            }
        }
    }
}
