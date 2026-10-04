package com.entaku.VoiceYourText.voicevox

import com.entaku.VoiceYourText.tts.TextRange
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.time.Instant

class VoicevoxSpeechPlayerTest {
    @get:Rule
    val temp = TemporaryFolder()

    private class FakeOutput : VoicevoxAudioOutput {
        val played = mutableListOf<String>()
        override suspend fun play(file: File) {
            played += file.readText()
        }
        override fun stop() = Unit
    }

    private val usage = VoicevoxUsage("free", 5000, 5000, 0, Instant.parse("2026-11-01T00:00:00Z"))

    private fun runPlayer(
        text: String,
        offset: Int = 0,
        synthesize: suspend (String, Int, Double) -> ByteArray,
    ): Pair<List<VoicevoxSpeechPlayer.Event>, FakeOutput> = runBlocking {
        val output = FakeOutput()
        val events = mutableListOf<VoicevoxSpeechPlayer.Event>()
        val done = CompletableDeferred<Unit>()
        val player = VoicevoxSpeechPlayer(
            scope = CoroutineScope(coroutineContext),
            synthesize = synthesize,
            cache = VoicevoxAudioCache(temp.newFolder()),
            output = output,
            tempDir = temp.root,
            log = { _, _ -> },
        )
        player.play(text, 14, 1.0, offset) { event ->
            events += event
            if (event !is VoicevoxSpeechPlayer.Event.Sentence) done.complete(Unit)
        }
        withTimeout(5_000) { done.await() }
        events to output
    }

    @Test
    fun playsEverySentenceInOrderWithOffsetRanges() {
        val (events, output) = runPlayer("一。二。", offset = 10) { text, _, _ -> text.toByteArray() }
        assertEquals(listOf("一。", "二。"), output.played)
        assertEquals(
            listOf(
                VoicevoxSpeechPlayer.Event.Sentence(TextRange(10, 2)),
                VoicevoxSpeechPlayer.Event.Sentence(TextRange(12, 2)),
                VoicevoxSpeechPlayer.Event.Finished,
            ),
            events,
        )
    }

    @Test
    fun quotaExceededStopsAtThatSentence() {
        val (events, output) = runPlayer("一。二。") { text, _, _ ->
            if (text == "二。") throw VoicevoxException.QuotaExceeded(usage)
            text.toByteArray()
        }
        assertEquals(listOf("一。"), output.played)
        assertEquals(VoicevoxSpeechPlayer.Event.QuotaExceeded(usage, 2), events.last())
    }

    @Test
    fun networkFailureReportsResumePosition() {
        val (events, output) = runPlayer("一。二。") { _, _, _ -> throw IOException("offline") }
        assertEquals(emptyList<String>(), output.played)
        assertEquals(listOf(VoicevoxSpeechPlayer.Event.Failed(0)), events)
    }

    @Test
    fun cachedSentenceDoesNotCallServer() {
        val cacheDir = temp.newFolder()
        VoicevoxAudioCache(cacheDir).store("cached".toByteArray(), "一。", 14, 1.0)
        val calls = mutableListOf<String>()
        runBlocking {
            val output = FakeOutput()
            val done = CompletableDeferred<Unit>()
            VoicevoxSpeechPlayer(CoroutineScope(coroutineContext), { t, _, _ -> calls += t; t.toByteArray() },
                VoicevoxAudioCache(cacheDir), output, temp.root, log = { _, _ -> })
                .play("一。", 14, 1.0) { if (it == VoicevoxSpeechPlayer.Event.Finished) done.complete(Unit) }
            withTimeout(5_000) { done.await() }
            assertEquals(listOf("cached"), output.played)
        }
        assertEquals(emptyList<String>(), calls)
    }

    @Test
    fun cacheKeyMatchesIosFormat() {
        // iOS VoicevoxAudioCache.key と同じ材料（"speakerId|速度2桁|本文"）の SHA-256
        val expected = java.security.MessageDigest.getInstance("SHA-256")
            .digest("14|1.00|こんにちは".toByteArray()).joinToString("") { "%02x".format(it) }
        assertEquals(expected, VoicevoxAudioCache.key("こんにちは", 14, 1.0))
    }
}
