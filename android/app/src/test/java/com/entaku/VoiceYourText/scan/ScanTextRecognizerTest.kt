package com.entaku.VoiceYourText.scan

import org.junit.Assert.assertEquals
import org.junit.Test

class ScanTextRecognizerTest {
    @Test
    fun 空のページを除いてページの間を空行で区切る() {
        assertEquals("一ページ目\n二行目\n\n三ページ目", ScanTextRecognizer.joinPages(listOf(" 一ページ目\n二行目 ", "", "  ", "三ページ目")))
    }
}
