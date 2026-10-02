package com.entaku.VoiceYourText.pdf

import org.junit.Assert.assertEquals
import org.junit.Test

class PdfTextReaderTest {
    @Test
    fun 行末の空白とCRLFを整える() {
        assertEquals(
            "PDF読み上げのテストです。\nこれは二文目です。",
            PdfTextReader.clean("PDF読み上げのテストです。      \r\nこれは二文目です。   \r\n\r\n")
        )
    }
}
