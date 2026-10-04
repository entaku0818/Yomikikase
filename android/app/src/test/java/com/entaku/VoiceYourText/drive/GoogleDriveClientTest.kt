package com.entaku.VoiceYourText.drive

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.time.Instant

class GoogleDriveClientTest {
    private lateinit var server: MockWebServer
    private lateinit var client: GoogleDriveClient

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        client = GoogleDriveClient(baseUrl = server.url("/").toString())
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun listsDocsAndTextFiles() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                """{"files":[{"id":"1","name":"議事録","mimeType":"application/vnd.google-apps.document","modifiedTime":"2026-10-01T03:00:00.000Z"},
                   {"id":"2","name":"memo.txt","mimeType":"text/plain"}]}"""
            )
        )
        val files = client.listFiles("tok")
        assertEquals(
            listOf(
                DriveFile("1", "議事録", GoogleDriveClient.GOOGLE_DOC, Instant.parse("2026-10-01T03:00:00Z")),
                DriveFile("2", "memo.txt", "text/plain", null),
            ),
            files,
        )
        val request = server.takeRequest()
        assertEquals("Bearer tok", request.getHeader("Authorization"))
        val q = request.requestUrl!!.queryParameter("q")!!
        assertTrue(q.contains("text/markdown") && q.contains("trashed=false"))
    }

    @Test
    fun exportsGoogleDocAsPlainTextWithoutBom() = runBlocking {
        server.enqueue(MockResponse().setBody("\uFEFF本文"))
        val text = client.fetchText("tok", DriveFile("abc", "doc", GoogleDriveClient.GOOGLE_DOC, null))
        assertEquals("本文", text)
        val url = server.takeRequest().requestUrl!!
        assertEquals("/drive/v3/files/abc/export", url.encodedPath)
        assertEquals("text/plain", url.queryParameter("mimeType"))
    }

    @Test
    fun downloadsTextFileContent() = runBlocking {
        server.enqueue(MockResponse().setBody("hello"))
        assertEquals("hello", client.fetchText("tok", DriveFile("x", "a.md", "text/markdown", null)))
        assertEquals("media", server.takeRequest().requestUrl!!.queryParameter("alt"))
    }

    @Test
    fun unauthorizedIsReported() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(401))
        try {
            client.listFiles("expired")
            fail()
        } catch (_: DriveUnauthorizedException) {
        }
    }

    @Test
    fun titleDropsExtension() {
        assertEquals("memo", GoogleDriveClient.title(DriveFile("1", "memo.txt", "text/plain", null)))
        assertEquals("議事録", GoogleDriveClient.title(DriveFile("1", "議事録", GoogleDriveClient.GOOGLE_DOC, null)))
    }
}
