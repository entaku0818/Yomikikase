package com.entaku.VoiceYourText.tts

/**
 * 文単位の読み上げ位置を管理する（TextToSpeech に依存しない純粋なロジック）。
 * utteranceId は "セッション番号:文の番号"。stop/新しい読み上げでセッションが変わるので、
 * 古いセッションのコールバックは無視できる。
 */
class PlaybackQueue {
    var chunks: List<String> = emptyList()
        private set
    var currentIndex: Int = 0
        private set
    private var session: Int = 0

    fun start(text: String, maxLength: Int = SpeechChunker.DEFAULT_MAX_LENGTH): List<Pair<String, String>> {
        chunks = SpeechChunker.split(text, maxLength)
        currentIndex = 0
        session++
        return pending()
    }

    /** 一時停止。読んでいた位置は残し、止める前に積んだ文のコールバックは以後無視する */
    fun pause() {
        session++
    }

    /** 再開時に積み直す分（今読んでいた文から最後まで） */
    fun resume(): List<Pair<String, String>> {
        session++
        return pending()
    }

    fun clear() {
        chunks = emptyList()
        currentIndex = 0
        session++
    }

    /** onStart で呼ぶ。今のセッションの id なら読んでいる位置を更新して true */
    fun onChunkStarted(utteranceId: String?): Boolean {
        val index = indexOf(utteranceId) ?: return false
        currentIndex = index
        return true
    }

    /** onDone で呼ぶ。最後の文を読み終えたら true（＝最後まで聴いた） */
    fun isFinished(utteranceId: String?): Boolean {
        val index = indexOf(utteranceId) ?: return false
        return index == chunks.lastIndex
    }

    private fun pending(): List<Pair<String, String>> =
        chunks.withIndex().drop(currentIndex).map { (i, chunk) -> "$session:$i" to chunk }

    private fun indexOf(utteranceId: String?): Int? {
        val parts = utteranceId?.split(":") ?: return null
        if (parts.size != 2 || parts[0].toIntOrNull() != session) return null
        return parts[1].toIntOrNull()?.takeIf { it in chunks.indices }
    }
}
