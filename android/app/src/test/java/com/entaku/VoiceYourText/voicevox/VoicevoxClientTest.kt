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
    fun catalogComesFromServerAndCanChangeWithoutAppUpdate() = runBlocking {
        fun entry(id: Int) = """{"speakerId":$id,"character":"server character $id","style":"normal","credit":"credit $id","termsUrl":"https://example.com/voice"}"""
        fun catalog(id: Int) = """{"schemaVersion":1,"revision":"r$id","defaultSpeakerId":$id,"termsUrl":"https://example.com/terms","voices":[${entry(id)}],"credits":[${entry(id)},${entry(999)}]}"""
        server.enqueue(MockResponse().setBody(catalog(401)))
        server.enqueue(MockResponse().setBody(catalog(402)))
        val first = client.catalog()
        assertEquals("server character 401", first.voices.single().character)
        assertEquals(401, first.selection(-1))
        assertEquals(401, first.selection(401))
        assertEquals(2, first.credits.size)
        val next = client.catalog()
        assertEquals(402, next.selection(401))
        assertEquals("/v1/voices", server.takeRequest().path)
        assertEquals("/v1/voices", server.takeRequest().path)
        server.enqueue(MockResponse().setResponseCode(503).setBody("""{"error":"policy_unavailable"}"""))
        try { client.catalog(); fail("Must not silently restore a stale catalog") }
        catch (e: VoicevoxException.Server) { assertEquals(503, e.status) }
    }

    @Test
    fun emptyCatalogHasNoDefaultAndInvalidMetadataIsRejected() {
        val empty = """{"schemaVersion":1,"revision":"r","defaultSpeakerId":null,"termsUrl":"https://example.com/terms","voices":[],"credits":[]}"""
        val catalog = VoicevoxClient.parseCatalog(JSONObject(empty))
        assertEquals(null, catalog.selection(14))
        for (invalid in listOf(empty.replace(":null", ":14"), empty.replace("https:", "javascript:"), "{}")) {
            try { VoicevoxClient.parseCatalog(JSONObject(invalid)); fail("Invalid catalog accepted") }
            catch (_: Exception) { }
        }
    }

    @Test
    fun configurationChangesChunkSizeOnNextRead() = runBlocking {
        fun config(limit: Int) = """{"schemaVersion":1,"revision":"r$limit","voicevox":{"enabled":true,"freeMonthlyChars":120,"premiumMonthlyChars":800,"maxRequestChars":$limit}}"""
        server.enqueue(MockResponse().setBody(config(5)))
        server.enqueue(MockResponse().setBody(config(2)))
        assertEquals(listOf("あいうえお"), client.chunks("あいうえお").map { it.text })
        assertEquals(listOf("あい", "うえ", "お"), client.chunks("あいうえお").map { it.text })
        assertEquals("/v1/config", server.takeRequest().path)
        assertEquals("/v1/config", server.takeRequest().path)
    }

    @Test
    fun invalidDisabledOrUnavailableConfigurationDoesNotFallback() = runBlocking {
        val valid = """{"schemaVersion":1,"revision":"r1","voicevox":{"enabled":true,"freeMonthlyChars":120,"premiumMonthlyChars":800,"maxRequestChars":40}}"""
        for (body in listOf(valid.replace("true", "false"), valid.replace(":40", ":0"), valid.replace(":1,", ":2,"), "{}")) {
            server.enqueue(MockResponse().setBody(body))
            try {
                client.chunks("本文")
                fail("Invalid config must stop generation")
            } catch (_: Exception) { }
        }
        server.enqueue(MockResponse().setResponseCode(503).setBody("""{"error":"policy_unavailable"}"""))
        try {
            client.chunks("本文")
            fail("Unavailable config must stop generation")
        } catch (e: VoicevoxException.Server) {
            assertEquals("policy_unavailable", e.code)
        }
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
