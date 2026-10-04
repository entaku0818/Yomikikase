package com.entaku.VoiceYourText.voicevox

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.util.Base64

class VoicevoxClientTest {
    private lateinit var server: MockWebServer
    private lateinit var client: VoicevoxClient

    private val usageJson = """{"plan":"free","used":120,"limit":5000,"remaining":4880,"resetAt":"2026-11-01T00:00:00Z"}"""

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        VoicevoxClient.decodeBase64 = { Base64.getDecoder().decode(it) }
        client = VoicevoxClient(baseUrl = server.url("/").toString(), appCheckToken = { "token" }, userId = { "user-1" })
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun quotaSendsAuthHeadersAndParsesUsage() = runBlocking {
        server.enqueue(MockResponse().setBody(usageJson))
        val usage = client.quota()
        assertEquals(VoicevoxUsage("free", 120, 5000, 4880, Instant.parse("2026-11-01T00:00:00Z")), usage)
        val request = server.takeRequest()
        assertEquals("/v1/quota", request.path)
        assertEquals("token", request.getHeader("X-Firebase-AppCheck"))
        assertEquals("user-1", request.getHeader("X-User-ID"))
    }

    @Test
    fun parsesResetAtWithTimeZoneOffset() {
        // サーバーは日本時間（+09:00）で返す
        val usage = VoicevoxClient.parseUsage(JSONObject(usageJson.replace("2026-11-01T00:00:00Z", "2026-11-01T00:00:00+09:00")))
        assertEquals(Instant.parse("2026-10-31T15:00:00Z"), usage.resetAt)
    }

    @Test
    fun synthesizePostsTextAndDecodesAudio() = runBlocking {
        val audio = byteArrayOf(1, 2, 3)
        val encoded = Base64.getEncoder().encodeToString(audio)
        server.enqueue(MockResponse().setBody("""{"audio":"$encoded","format":"m4a","duration":1.0,"phrases":[],"usage":$usageJson}"""))
        assertArrayEquals(audio, client.synthesize("こんにちは。", 14, 1.25))
        val body = JSONObject(server.takeRequest().body.readUtf8())
        assertEquals("こんにちは。", body.getString("text"))
        assertEquals(14, body.getInt("speakerId"))
        assertEquals(1.25, body.getDouble("speedScale"), 0.0)
    }

    @Test
    fun quotaExceededCarriesUsage() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(429).setBody("""{"error":"quota_exceeded","usage":$usageJson}"""))
        try {
            client.synthesize("あ", 14, 1.0)
            fail()
        } catch (e: VoicevoxException.QuotaExceeded) {
            assertEquals(4880, e.usage.remaining)
        }
    }

    @Test
    fun serverErrorCarriesCode() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":"invalid_app_check"}"""))
        try {
            client.quota()
            fail()
        } catch (e: VoicevoxException.Server) {
            assertEquals(401, e.status)
            assertEquals("invalid_app_check", e.code)
        }
    }

    @Test
    fun missingTokenIsUnavailableWithoutCallingServer() = runBlocking {
        val noToken = VoicevoxClient(baseUrl = server.url("/").toString(), appCheckToken = { error("no token") }, userId = { "u" })
        try {
            noToken.quota()
            fail()
        } catch (e: VoicevoxException.Unavailable) {
            // コルーチンのスタック復元で例外が複製されることがあるので、原因の連鎖をたどって確かめる
            assertTrue(generateSequence(e.cause) { it.cause }.any { it is IllegalStateException })
        }
        assertEquals(0, server.requestCount)
    }
}
