package com.entaku.VoiceYourText.aozora

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS AozoraTextNormalizerTests と同じケース */
class AozoraTextNormalizerTest {
    private fun strip(s: String) = AozoraTextNormalizer.stripRubyAndAnnotations(s)

    @Test fun ルビが除去される() = assertEquals("吾輩は猫である。", strip("吾輩《わがはい》は猫である。"))
    @Test fun 範囲指定記号つきのルビが除去される() = assertEquals("一番獰悪な種族", strip("一番｜獰悪《どうあく》な種族"))
    @Test fun 一行に複数のルビ() = assertEquals("書生を捕えて煮て食う", strip("書生を捕《つかま》えて煮《に》て食う"))
    @Test fun 閉じ括弧のないルビは行末まで捨てる() = assertEquals("吾輩", strip("吾輩《わがはい"))
    @Test fun 山括弧のエスケープは文字として残る() = assertEquals("記号《これ》を含む", strip("記号※《これ※》を含む"))
    @Test fun 入力者注記が除去される() = assertEquals("一", strip("［＃８字下げ］一［＃「一」は中見出し］"))
    @Test fun 外字注記は米印ごと除去される() = assertEquals("と書く", strip("※［＃「言＋墟のつくり」、第4水準2-88-74］と書く"))
    @Test fun 入れ子の注記が途中で閉じない() = assertEquals("前後", strip("前［＃「※［＃「口＋世」、第3水準1-15-1］」に傍点］後"))
    @Test fun 注記ではない角括弧は残る() = assertEquals("［注意］はそのまま", strip("［注意］はそのまま"))
    @Test fun 米印単体は残る() = assertEquals("※誤植を疑った箇所", strip("※誤植を疑った箇所"))

    @Test fun 区切り線を判定できる() {
        assertTrue(AozoraTextNormalizer.isDividerLine("-------------------------------------------------------"))
        assertFalse(AozoraTextNormalizer.isDividerLine("-----"))
        assertFalse(AozoraTextNormalizer.isDividerLine("本文-----------"))
    }

    @Test fun 記号説明ヘッダと底本フッタが取り除かれる() {
        val doc = AozoraTextNormalizer.normalize(SAMPLE)
        assertEquals("吾輩は猫である", doc.title)
        assertEquals("夏目漱石", doc.author)
        assertEquals("底本：「夏目漱石全集1」ちくま文庫、筑摩書房", doc.colophon)
        assertTrue(doc.body.startsWith("一\n\n　吾輩は猫である。"))
        listOf("《", "》", "［＃", "｜", "\r").forEach { assertFalse(it, it in doc.body) }
    }

    @Test fun 注記だけの行を消したあとに空行が溜まらない() {
        val raw = listOf(
            "タイトル", "著者", "", "----------------------------------------", "【テキスト中に現れる記号について】",
            "----------------------------------------", "", "［＃改ページ］", "", "　本文の一行目。", "", "［＃改ページ］", "", "　本文の二行目。"
        ).joinToString("\r\n")
        assertEquals("　本文の一行目。\n\n　本文の二行目。", AozoraTextNormalizer.normalize(raw).body)
    }

    @Test fun 区切り線がないファイルは全体を本文として扱う() {
        val doc = AozoraTextNormalizer.normalize("　ルビ《るび》のある一行だけのテキスト。")
        assertEquals("　ルビのある一行だけのテキスト。", doc.body)
        assertEquals("", doc.title)
    }

    @Test fun 空文字でも落ちない() = assertEquals(AozoraTextNormalizer.Document("", "", "", ""), AozoraTextNormalizer.normalize(""))

    @Test fun ShiftJISをデコードできる() {
        val source = "吾輩は猫である。"
        assertEquals(source, AozoraTextNormalizer.decode(source.toByteArray(charset("windows-31j"))))
    }

    @Test fun 読めないバイト列はnull() = assertNull(AozoraTextNormalizer.decode(byteArrayOf(0xFF.toByte(), 0xFE.toByte())))

    companion object {
        val SAMPLE = listOf(
            "吾輩は猫である", "夏目漱石", "", "-------------------------------------------------------",
            "【テキスト中に現れる記号について】", "", "《》：ルビ", "（例）吾輩《わがはい》",
            "-------------------------------------------------------", "", "［＃８字下げ］一［＃「一」は中見出し］", "",
            "　吾輩《わがはい》は猫である。名前はまだ無い。",
            "　一番｜獰悪《どうあく》な種族であったそうだ。※［＃「言＋墟のつくり」、第4水準2-88-74］", "", "", "",
            "底本：「夏目漱石全集1」ちくま文庫、筑摩書房", "　　　1987（昭和62）年9月29日第1刷発行", "入力：柴田卓治",
        ).joinToString("\r\n")
    }
}

class AozoraClientTest {
    private val work = AozoraWork("000092", "蜘蛛の糸", "", "芥川竜之介", "https://www.aozora.gr.jp/cards/000879/card92.html", "https://example.com/92.zip")

    @Test
    fun 本文の前に作品名と著者末尾に出典を付ける() {
        val text = AozoraClient.readingText(work, AozoraTextNormalizer.Document("", "", "　本文。", "底本：「芥川龍之介全集」"))
        assertEquals("蜘蛛の糸\n芥川竜之介\n\n　本文。\n\n出典：青空文庫（https://www.aozora.gr.jp/cards/000879/card92.html）\n底本：「芥川龍之介全集」", text)
    }

    @Test
    fun ZIPの中のtxtを取り出す() {
        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { zip ->
            zip.putNextEntry(java.util.zip.ZipEntry("readme.html")); zip.write("x".toByteArray()); zip.closeEntry()
            zip.putNextEntry(java.util.zip.ZipEntry("kumo.txt")); zip.write("本文".toByteArray()); zip.closeEntry()
        }
        assertEquals("本文", AozoraClient.extractTxt(out.toByteArray()).decodeToString())
    }
}
