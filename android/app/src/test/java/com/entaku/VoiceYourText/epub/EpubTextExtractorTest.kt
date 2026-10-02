package com.entaku.VoiceYourText.epub

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class EpubTextExtractorTest {

    private val container = """<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>"""

    private val opf = """<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0">
  <metadata><dc:title>吾輩は猫である</dc:title></metadata>
  <manifest>
    <item id="c2" href="text/chap%202.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="text/chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img" href="images/cover.jpg" media-type="image/jpeg"/>
  </manifest>
  <spine><itemref idref="c1"/><itemref idref="c2"/></spine>
</package>"""

    private val chap1 = """<html><body><h1>一</h1><p>吾輩は<ruby>猫<rt>ねこ</rt></ruby>である。</p><p>名前はまだ無い。</p></body></html>"""
    private val chap2 = """<html><body><p>どこで生れたか<br/>とんと見当がつかぬ。</p></body></html>"""

    private fun epubBytes(): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            fun put(name: String, body: String) {
                zip.putNextEntry(ZipEntry(name)); zip.write(body.toByteArray()); zip.closeEntry()
            }
            put("mimetype", "application/epub+zip")
            put("META-INF/container.xml", container)
            put("OEBPS/content.opf", opf)
            put("OEBPS/text/chap1.xhtml", chap1)
            put("OEBPS/text/chap 2.xhtml", chap2)
            put("OEBPS/images/cover.jpg", "binary")
        }
        return out.toByteArray()
    }

    @Test
    fun spineの順に本文を取り出しルビは読まない() {
        val book = EpubTextExtractor.extract(EpubTextExtractor.unzipTextEntries(ByteArrayInputStream(epubBytes())))
        assertEquals("吾輩は猫である", book.title)
        assertEquals("一\n吾輩は猫である。\n名前はまだ無い。\n\nどこで生れたか\nとんと見当がつかぬ。", book.text)
    }

    @Test
    fun 画像は読み込まない() {
        val entries = EpubTextExtractor.unzipTextEntries(ByteArrayInputStream(epubBytes()))
        assertEquals(false, entries.containsKey("OEBPS/images/cover.jpg"))
    }

    @Test
    fun 相対パスを解決する() {
        assertEquals("OEBPS/text/a.xhtml", EpubTextExtractor.resolve("OEBPS", "text/a.xhtml#p1"))
        assertEquals("text/a b.xhtml", EpubTextExtractor.resolve("OEBPS", "../text/a%20b.xhtml"))
        assertEquals("a.xhtml", EpubTextExtractor.resolve("", "./a.xhtml"))
    }
}
