package com.entaku.VoiceYourText.kokoro

import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Opt-in: enable with -e kokoroModelTest true after provisioning pinned model assets. */
class KokoroPrototypeTest {
    @Test fun cancelledSynthesisPreservesCompletedAudioAndRemovesPartialFile() = runBlocking {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("kokoroModelTest") == "true")
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.filesDir, "kokoro")
        KokoroPrototype(directory).use { engine ->
            val completed = engine.synthesize("こんにちは。今日は東京で本を読みます。")
            val original = completed.file.readBytes()
            try {
                withTimeout(100) {
                    withContext(Dispatchers.Default) {
                        engine.synthesize("こんにちは。今日は東京で本を読みます。".repeat(12))
                    }
                }
                fail("Cancelled synthesis must not publish a WAV")
            } catch (expected: TimeoutCancellationException) {
                assertArrayEquals(original, completed.file.readBytes())
                assertFalse(directory.listFiles().orEmpty().any { it.extension == "partial" })
            }
        }
    }

    @Test fun synthesizeJapaneseShortAndLongText() = runBlocking {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("kokoroModelTest") == "true")
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.filesDir, "kokoro")
        val measurements = mutableListOf<String>()
        val start = System.nanoTime()
        KokoroPrototype(directory).use { engine ->
            measurements += "initializationMs=${(System.nanoTime() - start) / 1_000_000}"
            val sentence = "こんにちは。今日は東京の図書館で、日本語の本を読みます。"
            val audition = "朝、窓を開けると、少し冷たい風が部屋に入ってきました。昨日まで降っていた雨はやみ、道の向こうから鳥の声が聞こえます。今日は、いつもよりゆっくり歩いてみよう。そう思って駅までの道を変えると、小さなパン屋さんを見つけました。焼きたての香りにつられて扉を開けると、店主が笑顔で迎えてくれました。何気ない朝が、少しだけ特別に感じられたのです。"
            for ((label, text) in listOf("short" to sentence, "long" to sentence.repeat(12), "audition" to audition)) {
                val result = engine.synthesize(text)
                assertTrue(result.seconds > 0)
                val bytes = result.file.readBytes()
                assertEquals("RIFF", String(bytes.copyOfRange(0, 4)))
                val pcm = ByteBuffer.wrap(bytes, 44, bytes.size - 44).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                var peak = 0
                while (pcm.hasRemaining()) peak = maxOf(peak, kotlin.math.abs(pcm.get().toInt()))
                assertTrue("Generated audio must not be silent", peak > 100)
                if (label == "long") assertTrue(result.chunks > 1)
                result.file.copyTo(File(directory, "$label.wav"), overwrite = true)
                measurements += "$label chars=${text.length} phonemes=${result.phonemes.length} chunks=${result.chunks} synthesisMs=${result.synthesisMillis} audioSeconds=${result.seconds} rtf=${result.realTimeFactor} peak=$peak"
                File(directory, "metrics.txt").writeText(measurements.joinToString("\n"))
            }
        }
    }
}
