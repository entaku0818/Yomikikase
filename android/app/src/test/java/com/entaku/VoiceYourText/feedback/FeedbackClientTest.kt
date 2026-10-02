package com.entaku.VoiceYourText.feedback

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

class FeedbackClientTest {

    private lateinit var server: MockWebServer

    @Before fun setUp() { server = MockWebServer().apply { start() } }

    @After fun tearDown() { server.shutdown() }

    private fun client() = FeedbackClient(
        endpoint = server.url("/submitFeedback").toString(),
        appVersion = "1.2.0",
        osVersion = "Android 13",
        deviceModel = "Google Pixel 6",
    )

    @Test
    fun iOSと同じ項目をJSONでPOSTする() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(200))

        client().submit("音が\"小さい\"\n改行あり")

        val request = server.takeRequest()
        assertEquals("POST", request.method)
        assertTrue(request.getHeader("Content-Type")!!.startsWith("application/json"))
        assertEquals(
            """{"message":"音が\"小さい\"\n改行あり","appVersion":"1.2.0","osVersion":"Android 13","deviceModel":"Google Pixel 6"}""",
            request.body.readUtf8()
        )
    }

    @Test(expected = IOException::class)
    fun サーバーエラーは例外にする(): Unit = runBlocking {
        server.enqueue(MockResponse().setResponseCode(400))
        client().submit("テスト")
    }
}
