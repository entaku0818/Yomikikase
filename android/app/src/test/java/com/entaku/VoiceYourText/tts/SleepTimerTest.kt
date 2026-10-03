package com.entaku.VoiceYourText.tts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SleepTimerTest {

    @Test
    fun 選択肢はiOSと同じ() {
        assertEquals(
            listOf(5, 10, 15, 30, 45, 60).map { SleepTimerOption.Minutes(it) } + SleepTimerOption.EndOfText,
            SleepTimerOption.PRESETS
        )
    }

    @Test
    fun 時間指定は1秒ずつ減って0で期限切れ() {
        var state = SleepTimerState(SleepTimerOption.Minutes(5))
        assertEquals(300, state.remainingSeconds)
        repeat(299) { state = state.ticked() }
        assertFalse(state.isExpired)
        assertEquals("0:01", state.remainingText)
        state = state.ticked()
        assertTrue(state.isExpired)
    }

    @Test
    fun 文章の終わり指定は時間で切れない() {
        val state = SleepTimerState(SleepTimerOption.EndOfText).ticked()
        assertNull(state.remainingSeconds)
        assertFalse(state.isExpired)
        assertNull(state.remainingText)
    }

    @Test
    fun 残り時間の表示() {
        assertEquals("5:00", SleepTimerState.formatRemaining(300))
        assertEquals("1:00:00", SleepTimerState.formatRemaining(3600))
        assertEquals("0:00", SleepTimerState.formatRemaining(-3))
    }
}
