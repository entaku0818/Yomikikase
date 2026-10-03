package com.entaku.VoiceYourText.tts

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.entaku.VoiceYourText.R

/** スリープタイマーで選べる停止条件（iOS の SleepTimerOption と同じ選択肢）。 */
sealed class SleepTimerOption {
    /** 指定分数の経過で停止する。 */
    data class Minutes(val minutes: Int) : SleepTimerOption()

    /** いま読み上げている文章を読み終えたら停止する。 */
    data object EndOfText : SleepTimerOption()

    val totalSeconds: Int?
        get() = (this as? Minutes)?.minutes?.times(60)

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

    /** 残り時間（m:ss / 1時間以上は h:mm:ss）。文章の終わり指定なら null */
    val remainingText: String?
        get() = remainingSeconds?.let(::formatRemaining)

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

/** メニューに出す文言（iOS と同じ選択肢） */
@Composable
fun sleepTimerTitle(option: SleepTimerOption): String = when (option) {
    is SleepTimerOption.Minutes -> stringResource(R.string.sleep_timer_minutes, option.minutes)
    SleepTimerOption.EndOfText -> stringResource(R.string.sleep_timer_end_of_text)
}

/** 再生画面に出す残り時間 */
@Composable
fun sleepTimerDisplay(state: SleepTimerState): String =
    state.remainingText ?: stringResource(R.string.sleep_timer_until_end)
