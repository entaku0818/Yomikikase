//
//  HTMLTextExtractorTests.swift
//  VoiceYourTextTests
//

import XCTest
@testable import VoiceYourText

final class HTMLTextExtractorTests: XCTestCase {

    // MARK: - タグ除去

    func test_基本的なHTMLタグを除去できる() {
        let html = "<p>Hello, <strong>World</strong>!</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "Hello, World!")
    }

    func test_divタグを改行に変換できる() {
        let html = "<div>First</div><div>Second</div>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("First"))
        XCTAssertTrue(result.contains("Second"))
        XCTAssertTrue(result.contains("\n"))
    }

    func test_pタグを改行に変換できる() {
        let html = "<p>First paragraph</p><p>Second paragraph</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("First paragraph"))
        XCTAssertTrue(result.contains("Second paragraph"))
    }

    func test_属性付きタグも除去できる() {
        let html = #"<a href="https://example.com" class="link">Click here</a>"#
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "Click here")
    }

    func test_ネストしたタグを除去できる() {
        let html = "<div><p><span>Nested text</span></p></div>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "Nested text")
    }

    // MARK: - スクリプト・スタイルブロック除去

    func test_scriptブロックを除去できる() {
        let html = "<p>Text</p><script>alert('hello');</script><p>More text</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("alert"))
        XCTAssertTrue(result.contains("Text"))
        XCTAssertTrue(result.contains("More text"))
    }

    func test_styleブロックを除去できる() {
        let html = "<style>body { color: red; }</style><p>Content</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("color"))
        XCTAssertTrue(result.contains("Content"))
    }

    func test_headブロックを除去できる() {
        let html = "<head><title>Page Title</title><meta charset='utf-8'></head><body><p>Body text</p></body>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("Page Title"))
        XCTAssertTrue(result.contains("Body text"))
    }

    func test_複数行のscriptブロックを除去できる() {
        let html = """
        <p>Before</p>
        <script type="text/javascript">
            var x = 1;
            var y = 2;
            console.log(x + y);
        </script>
        <p>After</p>
        """
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("console"))
        XCTAssertTrue(result.contains("Before"))
        XCTAssertTrue(result.contains("After"))
    }

    // MARK: - HTMLエンティティデコード

    func test_ampエンティティをデコードできる() {
        let html = "<p>AT&amp;T</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "AT&T")
    }

    func test_ltgtエンティティをデコードできる() {
        let html = "<p>&lt;code&gt;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "<code>")
    }

    func test_nbspエンティティをデコードできる() {
        let html = "<p>Hello&nbsp;World</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Hello") && result.contains("World"))
    }

    func test_quotエンティティをデコードできる() {
        let html = "<p>&quot;quoted&quot;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "\"quoted\"")
    }

    func test_10進数エンティティをデコードできる() {
        // &#65; = 'A'
        let html = "<p>&#65;&#66;&#67;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "ABC")
    }

    func test_16進数エンティティをデコードできる() {
        // &#x4E2D;&#x6587; = "中文"
        let html = "<p>&#x4E2D;&#x6587;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "中文")
    }

    func test_日本語の16進数エンティティをデコードできる() {
        // &#x3053;&#x3093;&#x306B;&#x3061;&#x306F; = "こんにちは"
        let html = "<p>&#x3053;&#x3093;&#x306B;&#x3061;&#x306F;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "こんにちは")
    }

    // MARK: - 空白正規化

    func test_先頭末尾の空白を除去できる() {
        let html = "   <p>Text</p>   "
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.hasPrefix(" "))
        XCTAssertFalse(result.hasSuffix(" "))
    }

    func test_複数の空白を1つに正規化できる() {
        let html = "<p>Word1  Word2   Word3</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("  "))
        XCTAssertTrue(result.contains("Word1 Word2 Word3"))
    }

    func test_3連続以上の改行を2つに正規化できる() {
        let html = "<p>First</p>\n\n\n\n<p>Second</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("\n\n\n"))
    }

    // MARK: - 実用的なHTMLテスト

    func test_実際のNHKニュース的なHTMLから本文を抽出できる() {
        let html = """
        <html>
        <head><title>ニュース</title></head>
        <body>
        <header><nav>ナビゲーション</nav></header>
        <article>
            <h1>今日のニュース見出し</h1>
            <p>本文の最初のパラグラフです。</p>
            <p>本文の2番目のパラグラフです。</p>
        </article>
        <script>trackPageView();</script>
        </body>
        </html>
        """
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("今日のニュース見出し"))
        XCTAssertTrue(result.contains("本文の最初のパラグラフです"))
        XCTAssertFalse(result.contains("trackPageView"))
    }

    func test_空のHTMLで空文字を返す() {
        let html = "<html><head></head><body></body></html>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.isEmpty)
    }

    func test_テキストのみの入力はそのまま返る() {
        let text = "これはHTMLタグのない普通のテキストです。"
        let result = HTMLTextExtractor.extract(from: text)
        XCTAssertEqual(result, text)
    }

    // MARK: - 空・空白入力

    func test_空文字列で空文字を返す() {
        let result = HTMLTextExtractor.extract(from: "")
        XCTAssertTrue(result.isEmpty)
    }

    func test_空白のみで空文字を返す() {
        let result = HTMLTextExtractor.extract(from: "   \n\t  ")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - br・見出しタグ

    func test_brタグを改行に変換できる() {
        let html = "<p>Line1<br>Line2<br/>Line3</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Line1"))
        XCTAssertTrue(result.contains("Line2"))
        XCTAssertTrue(result.contains("Line3"))
        XCTAssertTrue(result.contains("\n"))
    }

    func test_h1からh6タグが改行付きで取り出せる() {
        let html = "<h1>Heading 1</h1><h2>Heading 2</h2><h3>H3</h3>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Heading 1"))
        XCTAssertTrue(result.contains("Heading 2"))
        XCTAssertTrue(result.contains("H3"))
        XCTAssertTrue(result.contains("\n"))
    }

    func test_liタグが改行で区切られる() {
        let html = "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Item 1"))
        XCTAssertTrue(result.contains("Item 2"))
        XCTAssertTrue(result.contains("\n"))
    }

    // MARK: - HTMLコメント

    func test_HTMLコメントを除去できる() {
        let html = "<!-- This is a comment --><p>Visible text</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("This is a comment"))
        XCTAssertTrue(result.contains("Visible text"))
    }

    func test_複数行のHTMLコメントを除去できる() {
        let html = """
        <p>Before</p>
        <!--
            Multi-line
            comment here
        -->
        <p>After</p>
        """
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("Multi-line"))
        XCTAssertTrue(result.contains("Before"))
        XCTAssertTrue(result.contains("After"))
    }

    // MARK: - タブ文字の正規化

    func test_タブ文字がスペースに変換される() {
        let html = "<p>Word1\tWord2</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertFalse(result.contains("\t"))
        XCTAssertTrue(result.contains("Word1"))
        XCTAssertTrue(result.contains("Word2"))
    }

    // MARK: - 追加HTMLエンティティ

    func test_mdashエンティティをデコードできる() {
        let html = "<p>before&mdash;after</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "before\u{2014}after")
    }

    func test_ndashエンティティをデコードできる() {
        let html = "<p>2020&ndash;2024</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "2020\u{2013}2024")
    }

    func test_hellipエンティティをデコードできる() {
        let html = "<p>続く&hellip;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "続く\u{2026}")
    }

    func test_aposエンティティをデコードできる() {
        let html = "<p>it&apos;s</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "it's")
    }

    func test_copyエンティティをデコードできる() {
        let html = "<p>&copy; 2024 Example</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "\u{00A9} 2024 Example")
    }

    func test_regエンティティをデコードできる() {
        let html = "<p>Brand&reg;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "Brand\u{00AE}")
    }

    func test_laquoRaquoエンティティをデコードできる() {
        let html = "<p>&laquo;quoted&raquo;</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertEqual(result, "\u{00AB}quoted\u{00BB}")
    }

    // MARK: - malformed HTML

    func test_閉じタグなしのHTMLでもクラッシュしない() {
        let html = "<p>Unclosed paragraph<div>No closing tags"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Unclosed paragraph"))
        XCTAssertTrue(result.contains("No closing tags"))
    }

    func test_imgタグなど自己終了タグでもテキストを抽出できる() {
        let html = #"<p>Text<img src="image.png" alt="image"/>More text</p>"#
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Text"))
        XCTAssertTrue(result.contains("More text"))
        XCTAssertFalse(result.contains("src="))
    }

    func test_blockquoteタグが改行に変換される() {
        let html = "<blockquote>Quoted text</blockquote><p>Normal text</p>"
        let result = HTMLTextExtractor.extract(from: html)
        XCTAssertTrue(result.contains("Quoted text"))
        XCTAssertTrue(result.contains("Normal text"))
    }
}
