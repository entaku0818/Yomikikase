package com.entaku.VoiceYourText.kokoro

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class KokoroPhonemeChunkerTest {
    @Test fun shortInputIsUnchanged() {
        val text = "koɲɲitɕiwa. kʲoːwa iːteŋkʲidesɯ."
        assertEquals(listOf(text), KokoroPhonemeChunker.chunks(text))
    }

    @Test fun sentenceKeepsClosingQuoteAndSpace() {
        val sentence = "a".repeat(90) + ".\" "
        val rest = "i".repeat(80)
        assertEquals(listOf(sentence, rest), KokoroPhonemeChunker.chunks(sentence + rest))
    }

    @Test fun shortSentencesAreGroupedWithoutLosingWhitespace() {
        val text = "a. ".repeat(60)
        val chunks = KokoroPhonemeChunker.chunks(text)
        assertEquals(2, chunks.size)
        assertEquals(text, chunks.joinToString(""))
        assertTrue(chunks.all { it.length in 20..120 })
    }

    @Test fun longSentenceUsesPhraseBoundary() {
        val phrase = "a".repeat(90) + " "
        val rest = "i".repeat(70)
        assertEquals(listOf(phrase, rest), KokoroPhonemeChunker.chunks(phrase + rest))
    }

    @Test fun unpunctuatedTextIsBoundedWithoutDroppingPhonemes() {
        val text = "tɕoː".repeat(400)
        val chunks = KokoroPhonemeChunker.chunks(text)
        assertEquals(text, chunks.joinToString(""))
        assertTrue(chunks.all { it.isNotEmpty() && it.length <= 120 })
    }

    @Test fun tinyFinalTailIsBalanced() {
        assertEquals(listOf(60, 61), KokoroPhonemeChunker.chunks("a".repeat(121)).map { it.length })
        assertEquals(listOf("a".repeat(120)), KokoroPhonemeChunker.chunks("a".repeat(120)))
    }

    @Test fun emptyInputDoesNotInvokeInference() = runBlocking {
        assertEquals(0, KokoroPhonemeChunker.synthesize("") { fail("Empty inference") })
    }

    @Test fun rendersInOrderWithoutAddingPauses() = runBlocking {
        val rendered = mutableListOf<String>()
        val text = "a".repeat(121)
        assertEquals(2, KokoroPhonemeChunker.synthesize(text) { rendered += it })
        assertEquals(text, rendered.joinToString(""))
    }

    @Test fun failureDoesNotContinueToNextChunk() = runBlocking {
        var count = 0
        try {
            KokoroPhonemeChunker.synthesize("a".repeat(360)) {
                count++
                if (count == 2) throw IllegalStateException("inference failed")
            }
            fail("Partial synthesis must not succeed")
        } catch (expected: IllegalStateException) {
            assertEquals("inference failed", expected.message)
        }
        assertEquals(2, count)
    }

    @Test fun cancellationStopsNextChunkAndDiscardsFinalChunk() = runBlocking {
        for (length in listOf(30, 360)) {
            var count = 0
            var cancelled = false
            val job = launch {
                try {
                    KokoroPhonemeChunker.synthesize("a".repeat(length)) {
                        count++
                        currentCoroutineContext().cancel()
                    }
                    fail("Cancelled synthesis must not succeed")
                } catch (expected: CancellationException) { cancelled = true }
            }
            job.join()
            assertEquals(1, count)
            assertTrue(cancelled)
        }
    }
}
