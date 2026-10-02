package com.entaku.VoiceYourText.epub

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import org.jsoup.nodes.Node
import org.jsoup.nodes.TextNode
import org.jsoup.parser.Parser
import org.jsoup.select.NodeVisitor
import java.io.InputStream
import java.net.URLDecoder
import java.util.zip.ZipInputStream

data class EpubBook(val title: String?, val text: String)

/**
 * EPUB から読み上げ用の本文を取り出す（iOS `Features/EPUB/EPUBTextExtractor.swift` と同じ手順）。
 * META-INF/container.xml → OPF → spine の順に XHTML を読み、本文をつなげる。
 * ルビ（rt / rp）は二重に読まないよう除く。DRM 付きの EPUB は読めない。
 */
object EpubTextExtractor {

    /** 画像などは読まずに捨てる（メモリ節約）。合計がこれを超える EPUB は諦める */
    private const val MAX_TOTAL_BYTES = 64L * 1024 * 1024
    private val TEXT_EXTENSIONS = listOf(".xml", ".opf", ".xhtml", ".html", ".htm")

    suspend fun read(context: Context, uri: Uri): Result<EpubBook> = withContext(Dispatchers.IO) {
        runCatching {
            val input = context.contentResolver.openInputStream(uri) ?: error("EPUB ファイルを開けませんでした")
            input.use { extract(unzipTextEntries(it)) }
        }
    }

    fun unzipTextEntries(input: InputStream): Map<String, ByteArray> {
        val entries = mutableMapOf<String, ByteArray>()
        var total = 0L
        ZipInputStream(input).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                val name = entry.name
                if (!entry.isDirectory && TEXT_EXTENSIONS.any { name.endsWith(it, ignoreCase = true) }) {
                    val bytes = zip.readBytes()
                    total += bytes.size
                    check(total <= MAX_TOTAL_BYTES) { "EPUB が大きすぎます" }
                    entries[name] = bytes
                }
                zip.closeEntry()
            }
        }
        return entries
    }

    fun extract(entries: Map<String, ByteArray>): EpubBook {
        val container = entries["META-INF/container.xml"] ?: error("EPUB の構造が読めませんでした（container.xml が無い）")
        val opfPath = Jsoup.parse(container.decodeToString(), "", Parser.xmlParser())
            .selectFirst("rootfile")?.attr("full-path")?.takeIf { it.isNotBlank() }
            ?: error("EPUB の構造が読めませんでした（OPF が無い）")
        val opfBytes = entries[opfPath] ?: error("EPUB の構造が読めませんでした（$opfPath が無い）")
        val opf = Jsoup.parse(opfBytes.decodeToString(), "", Parser.xmlParser())
        val opfDir = opfPath.substringBeforeLast('/', "")

        val manifest = opf.select("manifest > item").associate { it.attr("id") to it.attr("href") }
        val spine = opf.select("spine > itemref").mapNotNull { manifest[it.attr("idref")] }
        val title = opf.selectFirst("metadata > dc|title, metadata > title")?.text()?.takeIf { it.isNotBlank() }

        val text = spine.mapNotNull { href ->
            entries[resolve(opfDir, href)]?.let { xhtmlToText(it.decodeToString()) }
        }.filter { it.isNotBlank() }.joinToString("\n\n")

        check(text.isNotBlank()) { "本文を取り出せませんでした（DRM 付きの本は読めません）" }
        return EpubBook(title, text)
    }

    /** OPF からの相対パスを ZIP 内のパスにする（%20 などをデコードし、#以降は捨てる） */
    fun resolve(baseDir: String, href: String): String {
        val path = URLDecoder.decode(href.substringBefore('#'), "UTF-8")
        val parts = (if (baseDir.isEmpty()) emptyList() else baseDir.split('/')).toMutableList()
        path.split('/').forEach { part ->
            when (part) {
                "", "." -> Unit
                ".." -> if (parts.isNotEmpty()) parts.removeAt(parts.lastIndex)
                else -> parts += part
            }
        }
        return parts.joinToString("/")
    }

    private val BLOCK_TAGS = setOf(
        "p", "div", "br", "li", "h1", "h2", "h3", "h4", "h5", "h6", "tr", "blockquote", "section", "article", "hr"
    )

    /** XHTML の本文を、段落ごとに改行を入れた文字列にする */
    fun xhtmlToText(xhtml: String): String {
        val body = Jsoup.parse(xhtml).body()
        body.select("rt, rp, script, style").remove()
        val out = StringBuilder()
        body.traverse(object : NodeVisitor {
            override fun head(node: Node, depth: Int) {
                if (node is TextNode) out.append(node.text())
                else if (node is Element && node.normalName() == "br") out.append('\n')
            }

            override fun tail(node: Node, depth: Int) {
                if (node is Element && node.normalName() in BLOCK_TAGS && node.normalName() != "br" && out.isNotEmpty() && out.last() != '\n') {
                    out.append('\n')
                }
            }
        })
        return out.lines().joinToString("\n") { it.trim() }.replace(Regex("\n{3,}"), "\n\n").trim()
    }
}
