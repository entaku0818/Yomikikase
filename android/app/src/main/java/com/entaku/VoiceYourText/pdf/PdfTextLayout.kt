package com.entaku.VoiceYourText.pdf

import kotlin.math.abs

/**
 * PDF から取り出した文字と、その文字がページのどこにあるか。
 * タップした位置から読み上げる（#138）ために使う。座標はページの幅・高さに対する割合（0〜1、左上が原点）。
 */
data class PdfGlyph(
    /** rawText 上の位置 */
    val offset: Int,
    val page: Int,
    val x: Float,
    val y: Float,
)

data class PdfTextLayout(
    /** ページ順に結合した本文（整形前。glyph の offset はこの文字列上の位置） */
    val rawText: String,
    val glyphs: List<PdfGlyph>,
) {
    /** 読み上げ・表示用に整形した本文 */
    val text: String get() = PdfTextReader.clean(rawText)

    /**
     * page の (x, y)（割合）をタップしたとき、読み始める位置（rawText 上）を返す。
     * いちばん近い文字を探し、その文の頭まで戻す（語の途中から読み始めないように）。
     * そのページに文字が無ければ null。
     */
    fun startOffsetAt(page: Int, x: Float, y: Float): Int? {
        // 行のずれ（y）を重く見て、同じ行の中で一番近い文字を選ぶ
        val nearest = glyphs.filter { it.page == page }
            .minByOrNull { abs(it.y - y) * 3 + abs(it.x - x) }
            ?: return null
        return sentenceStart(rawText, nearest.offset)
    }

    /** offset 以降を読み上げ用に整形した文字列 */
    fun textFrom(offset: Int): String = PdfTextReader.clean(rawText.substring(offset.coerceIn(0, rawText.length)))

    companion object {
        private const val SENTENCE_ENDS = "。．！？!?\n"

        /** offset を含む文の先頭（直前の文末記号・改行の次）の位置 */
        fun sentenceStart(text: String, offset: Int): Int {
            var i = offset.coerceIn(0, text.length)
            while (i > 0 && text[i - 1] !in SENTENCE_ENDS) i--
            // 文頭の空白は飛ばす
            while (i < text.length && text[i].isWhitespace()) i++
            return i
        }
    }
}
