package com.entaku.VoiceYourText.ads

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/** iOS AppOpenAdGateTests と同じルール */
class AppOpenAdGateTest {
    @Test
    fun 三回に一回だけ出す() {
        val shown = (1..9).filter { AppOpenAdGate.shouldShow(it, isPremium = false, hasCompletedOnboarding = true) }
        assertEquals(listOf(3, 6, 9), shown)
    }

    @Test
    fun プレミアム会員には出さない() = assertFalse(AppOpenAdGate.shouldShow(3, isPremium = true, hasCompletedOnboarding = true))

    @Test
    fun オンボーディング中は出さない() = assertFalse(AppOpenAdGate.shouldShow(3, isPremium = false, hasCompletedOnboarding = false))

    @Test
    fun 起動回数が0以下なら出さない() = assertFalse(AppOpenAdGate.shouldShow(0, isPremium = false, hasCompletedOnboarding = true))
}
