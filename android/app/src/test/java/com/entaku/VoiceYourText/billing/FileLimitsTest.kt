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

class CountedFilesTest {
    private fun file(type: com.entaku.VoiceYourText.file.SourceType) =
        com.entaku.VoiceYourText.file.SavedFileEntity(type.name + Math.random(), "t", "c", type, 0, 0)

    @org.junit.Test
    fun 入力して読み上げた文章は数えない() {
        val files = listOf(
            file(com.entaku.VoiceYourText.file.SourceType.TYPED),
            file(com.entaku.VoiceYourText.file.SourceType.TYPED),
            file(com.entaku.VoiceYourText.file.SourceType.PDF),
            file(com.entaku.VoiceYourText.file.SourceType.LINK),
        )
        org.junit.Assert.assertEquals(2, FileLimits.countedFiles(files))
    }
}
