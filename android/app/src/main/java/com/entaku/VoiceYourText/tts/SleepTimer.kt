package com.entaku.VoiceYourText.tts

/** スリープタイマーで選べる停止条件（iOS の SleepTimerOption と同じ選択肢）。 */
sealed class SleepTimerOption {
    /** 指定分数の経過で停止する。 */
    data class Minutes(val minutes: Int) : SleepTimerOption()

    /** いま読み上げている文章を読み終えたら停止する。 */
    data object EndOfText : SleepTimerOption()

    val totalSeconds: Int?
        get() = (this as? Minutes)?.minutes?.times(60)

    val title: String
        get() = when (this) {
            is Minutes -> "${minutes}分後に停止"
            EndOfText -> "この文章の終わりで停止"
        }

    companion object {
        val PRESETS: List<SleepTimerOption> = listOf(5, 10, 15, 30, 45, 60).map(::Minutes) + EndOfText
    }
}

/** 作動中のスリープタイマー。remainingSeconds は EndOfText なら null。 */
data class SleepTimerState(
    val option: SleepTimerOption,
    val remainingSeconds: Int? = option.totalSeconds,
) {
    /** 1秒進めた状態を返す */
    fun ticked(): SleepTimerState =
        copy(remainingSeconds = remainingSeconds?.let { maxOf(0, it - 1) })

    /** 時間指定で残り0になったら true */
    val isExpired: Boolean
        get() = remainingSeconds == 0

    /** 再生画面に出す残り時間（m:ss / 1時間以上は h:mm:ss） */
    val displayText: String
        get() = remainingSeconds?.let(::formatRemaining) ?: "文章の終わりまで"

    companion object {
        fun formatRemaining(seconds: Int): String {
            val s = maxOf(0, seconds)
            val h = s / 3600
            val m = (s % 3600) / 60
            val sec = s % 60
            return if (h > 0) "%d:%02d:%02d".format(h, m, sec) else "%d:%02d".format(m, sec)
        }
    }
}
