package com.entaku.VoiceYourText.kokoro

import com.entaku.VoiceYourText.tts.VoicePreset
import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class KokoroIntegrationTest {
    @get:Rule val folder = TemporaryFolder()

    @Test fun allFiveVoicesRoundTripThroughSavedPreset() {
        assertEquals(5, KokoroVoice.entries.map { it.voiceId }.toSet().size)
        KokoroVoice.entries.forEach { voice ->
            val preset = VoicePreset(null, null, 1.2f, 1f, voice.voiceId)
            assertEquals(preset, VoicePreset.decode(preset.encode()))
            assertEquals(voice, KokoroVoice.fromId(preset.kokoroVoice))
        }
    }

    @Test fun legacyPresetKeepsDeviceVoice() {
        val preset = VoicePreset.decode("""{"voice":"device","speaker":null,"rate":1,"pitch":1}""")!!
        assertNull(preset.kokoroVoice)
        assertEquals("device", preset.voiceName)
    }

    @Test fun verifiedDownloadIsAtomicAndReusableOffline() = runBlocking {
        val data = ByteArray(1024) { it.toByte() }
        val directory = folder.newFolder()
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody(Buffer().write(data)))
            val store = KokoroModelStore(directory, server.url("/model").toString(), data.size.toLong(), digest(data))
            assertFalse(store.state.value.ready)
            store.download()
            assertTrue(store.state.value.ready)
            assertArrayEquals(data, store.verifiedModel().readBytes())
            store.download()
            assertEquals(1, server.requestCount)
            assertFalse(File(directory, "model.partial").exists())
        }
    }

    @Test fun badChecksumIsNeverMarkedReady() = runBlocking {
        val directory = folder.newFolder()
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody("broken"))
            val store = KokoroModelStore(directory, server.url("/model").toString(), 6, digest("correct".toByteArray()))
            try { store.download(); fail("Checksum must reject") } catch (_: java.io.IOException) { }
            assertFalse(store.state.value.ready)
            assertTrue(store.state.value.failed)
            assertFalse(store.modelFile.exists())
            assertFalse(File(directory, "model.partial").exists())
        }
    }

    @Test fun truncatedDownloadCanRetry() = runBlocking {
        val directory = folder.newFolder()
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody("short"))
            server.enqueue(MockResponse().setBody("complete"))
            val store = KokoroModelStore(directory, server.url("/model").toString(), 8, digest("complete".toByteArray()))
            try { store.download(); fail("Length must reject") } catch (_: java.io.IOException) { }
            store.download()
            assertEquals("complete", store.verifiedModel().readText())
        }
    }

    private fun digest(data: ByteArray) = MessageDigest.getInstance("SHA-256").digest(data).joinToString("") { "%02x".format(it) }
}
