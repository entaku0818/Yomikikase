package com.entaku.VoiceYourText.aozora

import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction

/**
 * 青空文庫のテキストを読み上げ用のプレーンテキストにする（iOS `AozoraTextNormalizer.swift` の移植）。
 * ルビ《》・｜、入力者注記［＃…］、外字注記※［＃…］、先頭の記号説明ブロック、末尾の底本情報を取り除く。
 * 記法の仕様: https://www.aozora.gr.jp/annotation/
 */
object AozoraTextNormalizer {

    data class Document(val title: String, val author: String, val body: String, val colophon: String)

    /** 青空文庫は Shift_JIS(CP932) 配布。JIS X 0213 と UTF-8 もフォールバックで試す。どれでも読めなければ null */
    fun decode(bytes: ByteArray): String? =
        listOf("windows-31j", "x-SJIS_0213", "UTF-8").firstNotNullOfOrNull { name ->
            runCatching {
                Charset.forName(name).newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString()
            }.getOrNull()
        }

    fun normalize(raw: String): Document {
        val lines = raw.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        val (header, afterHeader) = splitHeader(lines)
        val (bodyLines, colophon) = splitColophon(afterHeader)
        val meta = header.map { it.trim() }.filter { it.isNotEmpty() }
        val body = bodyLines.joinToString("\n") { stripRubyAndAnnotations(it).trimEnd(' ', '\t') }
        return Document(
            title = meta.firstOrNull()?.let(::stripRubyAndAnnotations).orEmpty(),
            author = if (meta.size >= 2) stripRubyAndAnnotations(meta.last()) else "",
            // 段落頭の全角スペースを潰さないよう、前後は改行だけを落とす
            body = collapseBlankLines(body).trim('\n'),
            colophon = stripRubyAndAnnotations(colophon).trim(' ', '\t'),
        )
    }

    /** 記号説明ブロックの区切り線（`-` が10個以上だけの行） */
    fun isDividerLine(line: String): Boolean {
        val trimmed = line.trim()
        return trimmed.length >= 10 && trimmed.all { it == '-' }
    }

    private fun splitHeader(lines: List<String>): Pair<List<String>, List<String>> {
        val dividers = lines.indices.filter { isDividerLine(lines[it]) }
        if (dividers.size < 2) return emptyList<String>() to lines
        return lines.subList(0, dividers[0]) to lines.subList(dividers[1] + 1, lines.size)
    }

    private fun splitColophon(lines: List<String>): Pair<List<String>, String> {
        val index = lines.indexOfFirst { val t = it.trim(); t.startsWith("底本：") || t.startsWith("底本:") }
        if (index < 0) return lines to ""
        return lines.subList(0, index) to lines[index]
    }

    /** 3行以上の連続改行を2行にまとめる */
    fun collapseBlankLines(text: String): String {
        var result = text
        while ("\n\n\n" in result) result = result.replace("\n\n\n", "\n\n")
        return result
    }

    /**
     * ルビと入力者注記を取り除く。注記は `［＃「※［＃…］」…］` のように入れ子になるので、
     * 正規表現ではなく1文字ずつ走査する。
     */
    fun stripRubyAndAnnotations(text: String): String {
        val out = StringBuilder(text.length)
        var i = 0
        while (i < text.length) {
            val c = text[i]
            if (c == '※' && i + 1 < text.length) {
                val next = text[i + 1]
                if (next == '［') { i = skipAnnotation(text, i + 1); continue }
                if (next == '《' || next == '》') { out.append(next); i += 2; continue }
            }
            if (c == '［' && i + 1 < text.length && text[i + 1] == '＃') { i = skipAnnotation(text, i); continue }
            if (c == '《') { i = skipRuby(text, i); continue }
            if (c == '｜') { i++; continue }
            out.append(c)
            i++
        }
        return out.toString()
    }

    private fun skipAnnotation(text: String, start: Int): Int {
        var depth = 0
        var i = start
        while (i < text.length) {
            when (text[i]) {
                '［' -> depth++
                '］' -> { depth--; if (depth == 0) return i + 1 }
            }
            i++
        }
        return text.length // 閉じ括弧が無い壊れた入力は行末まで捨てる
    }

    private fun skipRuby(text: String, start: Int): Int {
        val end = text.indexOf('》', start + 1)
        return if (end < 0) text.length else end + 1
    }
}
