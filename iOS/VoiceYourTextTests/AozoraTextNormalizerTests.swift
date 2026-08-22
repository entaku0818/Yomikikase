import XCTest
@testable import VoiceYourText

/// 青空文庫テキストの正規化ロジックのテスト。
/// ここが壊れると「吾輩わがはい」のようにルビが読み上げに混入する（issue #120）。
final class AozoraTextNormalizerTests: XCTestCase {

    // MARK: - ルビ

    func testルビが読み上げ本文から除去される() {
        let input = "吾輩《わがはい》は猫である。"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "吾輩は猫である。")
    }

    func test範囲指定記号つきのルビが除去される() {
        let input = "一番｜獰悪《どうあく》な種族"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "一番獰悪な種族")
    }

    func test1行に複数のルビがあっても全て除去される() {
        let input = "書生を捕《つかま》えて煮《に》て食う"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "書生を捕えて煮て食う")
    }

    func test閉じ括弧のないルビは行末まで捨てる() {
        let input = "吾輩《わがはい"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "吾輩")
    }

    func test山括弧そのものを表すエスケープは文字として残る() {
        // 青空文庫では本文中の 《 》 は ※《 ※》 と書かれる
        let input = "記号※《これ※》を含む"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "記号《これ》を含む")
    }

    // MARK: - 注記

    func test入力者注記が除去される() {
        let input = "［＃８字下げ］一［＃「一」は中見出し］"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "一")
    }

    func test外字注記は米印ごと除去される() {
        let input = "※［＃「言＋墟のつくり」、第4水準2-88-74］と書く"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "と書く")
    }

    func test入れ子になった注記が途中で閉じない() {
        let input = "前［＃「※［＃「口＋世」、第3水準1-15-1］」に傍点］後"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "前後")
    }

    func test注記ではない角括弧は本文として残る() {
        let input = "［注意］はそのまま"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "［注意］はそのまま")
    }

    func test米印単体は本文として残る() {
        let input = "※誤植を疑った箇所"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), "※誤植を疑った箇所")
    }

    func test記法を含まない文字列は変化しない() {
        let input = "名前はまだ無い。"
        XCTAssertEqual(AozoraTextNormalizer.stripRubyAndAnnotations(input), input)
    }

    // MARK: - ヘッダ / フッタ

    func test区切り線を判定できる() {
        XCTAssertTrue(AozoraTextNormalizer.isDividerLine("-------------------------"))
        XCTAssertFalse(AozoraTextNormalizer.isDividerLine("---"))
        XCTAssertFalse(AozoraTextNormalizer.isDividerLine("----------本文----------"))
    }

    func test記号説明ヘッダと底本フッタが本文から取り除かれる() {
        let document = AozoraTextNormalizer.normalize(Self.sampleFile)

        XCTAssertEqual(document.title, "吾輩は猫である")
        XCTAssertEqual(document.author, "夏目漱石")
        XCTAssertEqual(document.colophon, "底本：「夏目漱石全集1」ちくま文庫、筑摩書房")
        XCTAssertFalse(document.body.contains("【テキスト中に現れる記号について】"))
        XCTAssertFalse(document.body.contains("底本："))
        XCTAssertFalse(document.body.contains("入力："))
        XCTAssertFalse(document.body.contains("青空文庫作成ファイル"))
    }

    func test本文にルビと注記が残らない() {
        let document = AozoraTextNormalizer.normalize(Self.sampleFile)

        XCTAssertTrue(document.body.hasPrefix("一\n\n　吾輩は猫である。"))
        XCTAssertFalse(document.body.contains("《"))
        XCTAssertFalse(document.body.contains("》"))
        XCTAssertFalse(document.body.contains("［＃"))
        XCTAssertFalse(document.body.contains("｜"))
    }

    func testCRLF改行が本文に残らない() {
        let document = AozoraTextNormalizer.normalize(Self.sampleFile)
        XCTAssertFalse(document.body.contains("\r"))
    }

    func test注記だけの行を消したあとに空行が溜まらない() {
        let raw = [
            "タイトル",
            "著者",
            "",
            "----------------------------------------",
            "【テキスト中に現れる記号について】",
            "----------------------------------------",
            "",
            "［＃改ページ］",
            "",
            "　本文の一行目。",
            "",
            "［＃改ページ］",
            "",
            "　本文の二行目。"
        ].joined(separator: "\r\n")

        let document = AozoraTextNormalizer.normalize(raw)
        XCTAssertEqual(document.body, "　本文の一行目。\n\n　本文の二行目。")
        XCTAssertFalse(document.body.contains("\n\n\n"))
    }

    func test区切り線がないファイルは全体を本文として扱う() {
        let raw = "　ルビ《るび》のある一行だけのテキスト。"
        let document = AozoraTextNormalizer.normalize(raw)

        XCTAssertEqual(document.body, "　ルビのある一行だけのテキスト。")
        XCTAssertEqual(document.title, "")
        XCTAssertEqual(document.colophon, "")
    }

    func test空文字を渡しても落ちない() {
        let document = AozoraTextNormalizer.normalize("")
        XCTAssertEqual(document.body, "")
        XCTAssertEqual(document.title, "")
        XCTAssertEqual(document.author, "")
        XCTAssertEqual(document.colophon, "")
    }

    func test連続空行が2行にまとめられる() {
        XCTAssertEqual(AozoraTextNormalizer.collapseBlankLines("a\n\n\n\n\nb"), "a\n\nb")
        XCTAssertEqual(AozoraTextNormalizer.collapseBlankLines("a\n\nb"), "a\n\nb")
    }

    // MARK: - デコード

    func testShiftJISのデータをデコードできる() throws {
        let source = "吾輩は猫である"
        let data = try XCTUnwrap(source.data(using: .shiftJIS))
        XCTAssertEqual(AozoraTextNormalizer.decode(data), source)
    }

    func testASCIIのデータをデコードできる() throws {
        let source = "Aozora Bunko"
        let data = try XCTUnwrap(source.data(using: .ascii))
        XCTAssertEqual(AozoraTextNormalizer.decode(data), source)
    }

    func testどの文字コードでも読めないバイト列はnilを返す() {
        // 0xFF 0xFE は Shift_JIS / UTF-8 のどちらとしても不正
        XCTAssertNil(AozoraTextNormalizer.decode(Data([0xFF, 0xFE])))
    }

    // MARK: - Fixture

    /// 青空文庫の配布ファイル（夏目漱石「吾輩は猫である」）と同じ構造の縮小サンプル。CRLF改行。
    private static let sampleFile: String = [
        "吾輩は猫である",
        "夏目漱石",
        "",
        "-------------------------------------------------------",
        "【テキスト中に現れる記号について】",
        "",
        "《》：ルビ",
        "（例）吾輩《わがはい》",
        "-------------------------------------------------------",
        "",
        "［＃８字下げ］一［＃「一」は中見出し］",
        "",
        "　吾輩《わがはい》は猫である。名前はまだ無い。",
        "　一番｜獰悪《どうあく》な種族であったそうだ。※［＃「言＋墟のつくり」、第4水準2-88-74］",
        "",
        "",
        "",
        "底本：「夏目漱石全集1」ちくま文庫、筑摩書房",
        "　　　1987（昭和62）年9月29日第1刷発行",
        "入力：柴田卓治",
        "青空文庫作成ファイル：",
        "このファイルは、インターネットの図書館、青空文庫で作られました。"
    ].joined(separator: "\r\n")
}
