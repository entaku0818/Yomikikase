package com.entaku.VoiceYourText.file

import org.junit.Assert.assertEquals
import org.junit.Test

class TrashTest {
    private val day = 24L * 60 * 60 * 1000

    @Test
    fun 削除直後は7日() = assertEquals(7, trashDaysRemaining(deletedAt = 0, now = 0))

    @Test
    fun 半端な日は切り上げる() = assertEquals(7, trashDaysRemaining(deletedAt = 0, now = day / 2))

    @Test
    fun 六日たったら残り1日() = assertEquals(1, trashDaysRemaining(deletedAt = 0, now = 6 * day))

    @Test
    fun 保持期間を過ぎたら0() {
        assertEquals(0, trashDaysRemaining(deletedAt = 0, now = 7 * day))
        assertEquals(0, trashDaysRemaining(deletedAt = 0, now = 30 * day))
    }
}
