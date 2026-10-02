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
            listOf("5分後に停止", "10分後に停止", "15分後に停止", "30分後に停止", "45分後に停止", "60分後に停止", "この文章の終わりで停止"),
            SleepTimerOption.PRESETS.map { it.title }
        )
    }

    @Test
    fun 時間指定は1秒ずつ減って0で期限切れ() {
        var state = SleepTimerState(SleepTimerOption.Minutes(5))
        assertEquals(300, state.remainingSeconds)
        repeat(299) { state = state.ticked() }
        assertFalse(state.isExpired)
        assertEquals("0:01", state.displayText)
        state = state.ticked()
        assertTrue(state.isExpired)
    }

    @Test
    fun 文章の終わり指定は時間で切れない() {
        val state = SleepTimerState(SleepTimerOption.EndOfText).ticked()
        assertNull(state.remainingSeconds)
        assertFalse(state.isExpired)
        assertEquals("文章の終わりまで", state.displayText)
    }

    @Test
    fun 残り時間の表示() {
        assertEquals("5:00", SleepTimerState.formatRemaining(300))
        assertEquals("1:00:00", SleepTimerState.formatRemaining(3600))
        assertEquals("0:00", SleepTimerState.formatRemaining(-3))
    }
}
