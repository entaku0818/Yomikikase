package com.entaku.VoiceYourText.drive

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.IOException
import java.time.Instant

data class DriveFile(val id: String, val name: String, val mimeType: String, val modifiedTime: Instant?) {
    val isGoogleDoc: Boolean get() = mimeType == GoogleDriveClient.GOOGLE_DOC
}

/** アクセストークンが切れている・取り消された（もう一度許可をもらう） */
class DriveUnauthorizedException : IOException("drive unauthorized")

/**
 * Google ドライブ（REST API v3）から読み上げられるファイルを一覧・取得する（iOS GoogleDriveClient と同じ条件）。
 * 対象は Google ドキュメント（テキストに変換して取得）と .txt / .md。
 */
class GoogleDriveClient(
    private val baseUrl: String = BASE_URL,
    private val httpClient: OkHttpClient = OkHttpClient(),
) {
    suspend fun listFiles(accessToken: String): List<DriveFile> = withContext(Dispatchers.IO) {
        val url = "${baseUrl}drive/v3/files".toHttpUrl().newBuilder()
            .addQueryParameter("q", "($QUERY) and trashed=false")
            .addQueryParameter("fields", "files(id,name,mimeType,modifiedTime)")
            .addQueryParameter("orderBy", "modifiedTime desc")
            .addQueryParameter("pageSize", "50")
            .build()
        parseFiles(get(url.toString(), accessToken))
    }

    suspend fun fetchText(accessToken: String, file: DriveFile): String = withContext(Dispatchers.IO) {
        val url = "${baseUrl}drive/v3/files/${file.id}".toHttpUrl().newBuilder().apply {
            if (file.isGoogleDoc) {
                addPathSegment("export")
                addQueryParameter("mimeType", "text/plain")
            } else {
                addQueryParameter("alt", "media")
            }
        }.build()
        // Google ドキュメントの書き出しは先頭に BOM が付く
        get(url.toString(), accessToken).trimStart(BOM)
    }

    private fun get(url: String, accessToken: String): String {
        val request = Request.Builder().url(url).header("Authorization", "Bearer $accessToken").build()
        return httpClient.newCall(request).execute().use { response ->
            if (response.code == 401) throw DriveUnauthorizedException()
            if (!response.isSuccessful) throw IOException("drive HTTP ${response.code}")
            response.body?.string().orEmpty()
        }
    }

    companion object {
        const val BASE_URL = "https://www.googleapis.com/"
        private val BOM = Char(0xFEFF)
        const val SCOPE = "https://www.googleapis.com/auth/drive.readonly"
        const val GOOGLE_DOC = "application/vnd.google-apps.document"
        private const val QUERY = "mimeType='$GOOGLE_DOC' or mimeType='text/plain' or mimeType='text/markdown'"

        fun parseFiles(json: String): List<DriveFile> {
            val files = JSONObject(json).optJSONArray("files") ?: return emptyList()
            return (0 until files.length()).map { i ->
                val file = files.getJSONObject(i)
                DriveFile(
                    id = file.getString("id"),
                    name = file.getString("name"),
                    mimeType = file.getString("mimeType"),
                    modifiedTime = file.optString("modifiedTime").takeIf { it.isNotEmpty() }
                        ?.let { runCatching { Instant.parse(it) }.getOrNull() },
                )
            }
        }

        /** 取り込んだときのタイトル（拡張子は外す） */
        fun title(file: DriveFile): String = file.name.substringBeforeLast('.').ifBlank { file.name }
    }
}
