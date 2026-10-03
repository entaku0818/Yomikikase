package com.entaku.VoiceYourText.billing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FileLimitsTest {
    @Test
    fun 無料版は5件で上限() {
        assertFalse(FileLimits.hasReachedLimit(fileCount = 4, isPremium = false))
        assertTrue(FileLimits.hasReachedLimit(fileCount = 5, isPremium = false))
        assertTrue(FileLimits.hasReachedLimit(fileCount = 30, isPremium = false))
    }

    @Test
    fun プレミアムは上限なし() {
        assertFalse(FileLimits.hasReachedLimit(fileCount = 100, isPremium = true))
    }
}
