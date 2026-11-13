package com.entaku.VoiceYourText.kokoro

import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test

class KokoroProductionTest {
    @Test fun allFiveBundledVoicesGenerateRealAudioAndCancelCleanly() = runBlocking {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("kokoroModelTest") == "true")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val models = KokoroModelStore(File(context.noBackupFilesDir, "kokoro-v1"))
        val engine = KokoroSynthesizer(models, context.assets)
        val hashes = mutableSetOf<String>()
        try {
            for (voice in KokoroVoice.entries) {
                val bytes = engine.synthesize("こんにちは。この声で本を読みます。", voice, 1f)
                assertEquals("RIFF", String(bytes.copyOfRange(0, 4)))
                assertTrue(bytes.size > 48000)
                hashes += MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
                File(context.cacheDir, "production-${voice.voiceId}.wav").writeBytes(bytes)
            }
            assertEquals(5, hashes.size)
            try {
                withTimeout(100) {
                    engine.synthesize("窓を開けると風が入ってきました。".repeat(30), KokoroVoice.RIN, 1f)
                }
                fail("Cancellation must propagate")
            } catch (_: TimeoutCancellationException) { }
            assertTrue(engine.synthesize("再開します。", KokoroVoice.KUMO, 1f).size > 44)
        } finally { engine.close() }
    }
}
