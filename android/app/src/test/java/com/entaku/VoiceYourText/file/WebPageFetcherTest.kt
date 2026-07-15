package com.entaku.VoiceYourText.file

import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.TimeUnit

class WebPageFetcherTest {

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun `fetchText extracts title and body text from a successful HTML response`() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                "<html><head><title>テストページ</title></head><body><p>本文テキスト</p></body></html>"
            )
        )

        val result = WebPageFetcher.fetchText(server.url("/").toString())

        assertTrue(result.isSuccess)
        val page = result.getOrThrow()
        assertEquals("テストページ", page.title)
        assertTrue(page.text.contains("本文テキスト"))
    }

    @Test
    fun `fetchText fails with a message containing the status code on a 404 response`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(404))

        val result = WebPageFetcher.fetchText(server.url("/missing").toString())

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull()?.message.orEmpty().contains("404"))
    }

    @Test
    fun `fetchText fails with a message containing the status code on a 500 response`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(500))

        val result = WebPageFetcher.fetchText(server.url("/error").toString())

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull()?.message.orEmpty().contains("500"))
    }

    @Test
    fun `fetchText succeeds with blank text when the response body is empty`() = runBlocking {
        server.enqueue(MockResponse().setBody(""))

        val result = WebPageFetcher.fetchText(server.url("/").toString())

        assertTrue(result.isSuccess)
        assertTrue(result.getOrThrow().text.isBlank())
    }

    @Test
    fun `fetchText fails for a malformed URL`() = runBlocking {
        val result = WebPageFetcher.fetchText("not a valid url")

        assertTrue(result.isFailure)
    }

    @Test
    fun `fetchText fails when the connection is refused`() = runBlocking {
        val url = server.url("/").toString()
        server.shutdown()

        val result = WebPageFetcher.fetchText(url)

        assertTrue(result.isFailure)
    }

    @Test
    fun `fetchText fails on timeout`() = runBlocking {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        val shortTimeoutClient = OkHttpClient.Builder()
            .connectTimeout(1, TimeUnit.SECONDS)
            .readTimeout(1, TimeUnit.SECONDS)
            .build()

        val result = WebPageFetcher.fetchText(server.url("/").toString(), client = shortTimeoutClient)

        assertTrue(result.isFailure)
    }
}
