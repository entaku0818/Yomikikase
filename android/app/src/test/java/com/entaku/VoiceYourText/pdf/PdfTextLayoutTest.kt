package com.entaku.VoiceYourText.pdf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PdfTextLayoutTest {

    // 1ページ目: 「一文目です。二文目です。」を1行に並べ、2ページ目: 「三文目。」
    private val raw = "一文目です。二文目です。\n\n三文目。"
    private val layout = PdfTextLayout(
        rawText = raw,
        glyphs = (0 until 12).map { PdfGlyph(it, page = 0, x = 0.05f + it * 0.07f, y = 0.1f) } +
            (14 until 18).map { PdfGlyph(it, page = 1, x = 0.05f + (it - 14) * 0.07f, y = 0.1f) },
    )

    @Test
    fun タップした文字を含む文の頭から読む() {
        // 「二文目です。」の「目」(offset 8) あたりをタップ
        val offset = layout.startOffsetAt(page = 0, x = 0.05f + 8 * 0.07f, y = 0.11f)
        assertEquals(6, offset)
        assertEquals("二文目です。\n\n三文目。", layout.textFrom(offset!!))
    }

    @Test
    fun 二ページ目のタップはそのページの文から() {
        val offset = layout.startOffsetAt(page = 1, x = 0.1f, y = 0.1f)
        assertEquals(14, offset)
    }

    @Test
    fun 文字が無いページはnull() = assertNull(layout.startOffsetAt(page = 5, x = 0.5f, y = 0.5f))

    @Test
    fun 文頭の空白は飛ばす() {
        // 「い」(offset 3) の文の頭は、句点の後の空白を飛ばした位置 3
        assertEquals(3, PdfTextLayout.sentenceStart("あ。 い", 3))
    }
}
