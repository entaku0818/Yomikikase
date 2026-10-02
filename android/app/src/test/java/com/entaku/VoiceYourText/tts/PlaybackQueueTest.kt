package com.entaku.VoiceYourText.tts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SpeechChunkerTest {

    @Test
    fun 日本語と英語の文末で分ける() {
        assertEquals(
            listOf("今日は晴れ。", "明日は雨！", "Hello.", " World?"),
            SpeechChunker.split("今日は晴れ。明日は雨！Hello. World?")
        )
    }

    @Test
    fun 長すぎる文は上限ごとに切る() {
        assertEquals(listOf("あいう", "えお"), SpeechChunker.split("あいうえお", maxLength = 3))
    }

    @Test
    fun 空白だけの断片は捨てる() {
        assertEquals(listOf("一行目\n", "二行目"), SpeechChunker.split("一行目\n\n  \n二行目"))
    }
}

class PlaybackQueueTest {

    @Test
    fun 一時停止した文から再開する() {
        val queue = PlaybackQueue()
        val first = queue.start("一文目。二文目。三文目。")
        assertEquals(3, first.size)

        assertTrue(queue.onChunkStarted(first[1].first)) // 二文目を読み始めたところで一時停止
        val resumed = queue.resume()

        assertEquals(listOf("二文目。", "三文目。"), resumed.map { it.second })
    }

    @Test
    fun 再開後は古いセッションのコールバックを無視する() {
        val queue = PlaybackQueue()
        val first = queue.start("一文目。二文目。")
        queue.onChunkStarted(first[0].first)
        queue.resume()

        assertFalse(queue.onChunkStarted(first[1].first))
        assertFalse(queue.isFinished(first[1].first))
    }

    @Test
    fun 一時停止後に遅れて届いたコールバックは無視して位置を保つ() {
        val queue = PlaybackQueue()
        val chunks = queue.start("一文目。二文目。三文目。")
        queue.onChunkStarted(chunks[1].first)
        queue.pause()

        assertFalse(queue.onChunkStarted(chunks[2].first))
        assertEquals(listOf("二文目。", "三文目。"), queue.resume().map { it.second })
    }

    @Test
    fun 最後の文を読み終えたら完了() {
        val queue = PlaybackQueue()
        val chunks = queue.start("一文目。二文目。")

        assertFalse(queue.isFinished(chunks[0].first))
        assertTrue(queue.isFinished(chunks[1].first))
    }

    @Test
    fun 停止したら完了扱いにしない() {
        val queue = PlaybackQueue()
        val chunks = queue.start("一文目。")
        queue.clear()

        assertFalse(queue.isFinished(chunks[0].first))
    }
}

class HighlightRangeTest {

    @Test
    fun 文の中の位置をテキスト全体の位置にする() {
        val queue = PlaybackQueue()
        val chunks = queue.start("一文目。二文目です。")
        // 二文目（開始位置4）の「です」(2..4)
        assertEquals(TextRange(6, 2), queue.spokenRange(chunks[1].first, 2, 4))
    }

    @Test
    fun 空白だけの断片を捨てても位置はずれない() {
        val chunked = SpeechChunker.splitWithOffsets("一行目\n\n  \n二行目")
        assertEquals(listOf(TextChunk("一行目\n", 0), TextChunk("二行目", 8)), chunked)
    }

    @Test
    fun 整形で置き換えた語は元の語全体を指す() {
        val prepared = SpeechTextPreprocessor.prepare("PDFを開く。", "ja")
        val queue = PlaybackQueue()
        val chunks = queue.start(prepared.spoken)
        // 「ピーディーエフ」の途中(2..4)を読んでいる → 元の「PDF」(0..3)
        val spoken = queue.spokenRange(chunks[0].first, 2, 4)!!
        assertEquals(TextRange(0, 3), prepared.originalRange(spoken))
    }

    @Test
    fun 古いセッションの範囲は無視する() {
        val queue = PlaybackQueue()
        val chunks = queue.start("一文目。")
        queue.pause()
        assertEquals(null, queue.spokenRange(chunks[0].first, 0, 2))
    }
}
