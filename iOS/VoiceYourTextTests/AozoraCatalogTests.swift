import XCTest
@testable import VoiceYourText

/// 同梱の作品カタログ（Resources/AozoraCatalog.json）とその読み込みのテスト。
final class AozoraCatalogTests: XCTestCase {

    // MARK: - 同梱JSON

    func test同梱カタログがバンドルに含まれていて読み込める() throws {
        let catalog = try AozoraCatalogLoader.load()

        XCTAssertGreaterThanOrEqual(catalog.works.count, 20, "初回体験用に十分な作品数を同梱していること")
        XCTAssertEqual(catalog.version, 1)
        XCTAssertTrue(catalog.source.contains("aozora.gr.jp"))
    }

    func test同梱カタログの全作品が青空文庫の配布URLを指している() throws {
        let catalog = try AozoraCatalogLoader.load()

        for work in catalog.works {
            XCTAssertEqual(work.textZipURL.scheme, "https", "\(work.title): httpsで取得すること")
            XCTAssertEqual(work.textZipURL.host, "www.aozora.gr.jp", "\(work.title): 公式の配布経路のみ使うこと")
            XCTAssertTrue(work.textZipURL.lastPathComponent.hasSuffix(".zip"), "\(work.title)")
            XCTAssertEqual(work.cardURL.host, "www.aozora.gr.jp", "\(work.title): 出典表記用の図書カードURLを持つこと")
            XCTAssertFalse(work.title.isEmpty)
            XCTAssertFalse(work.author.isEmpty)
        }
    }

    func test同梱カタログの作品IDが重複していない() throws {
        let catalog = try AozoraCatalogLoader.load()
        let ids = catalog.works.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - デコード

    func testJSONをデコードできる() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))

        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.works.count, 2)
        XCTAssertEqual(catalog.works.first?.title, "蜘蛛の糸")
        XCTAssertEqual(catalog.works.first?.author, "芥川竜之介")
    }

    func test壊れたJSONはmalformedを投げる() {
        XCTAssertThrowsError(try AozoraCatalogLoader.decode(Data("{ not json".utf8))) { error in
            XCTAssertEqual(error as? AozoraCatalogLoader.LoadError, .malformed)
        }
    }

    // MARK: - 表示・絞り込み

    func test副題があれば表示タイトルに連結される() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        XCTAssertEqual(catalog.works[0].displayTitle, "蜘蛛の糸")
        XCTAssertEqual(catalog.works[1].displayTitle, "銀河鉄道の夜　初期形三")
    }

    func test作品名で絞り込める() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        XCTAssertEqual(catalog.filtered(by: "銀河").map(\.title), ["銀河鉄道の夜"])
    }

    func test著者名で絞り込める() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        XCTAssertEqual(catalog.filtered(by: "芥川").map(\.title), ["蜘蛛の糸"])
    }

    func test副題でも絞り込める() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        XCTAssertEqual(catalog.filtered(by: "初期形").map(\.title), ["銀河鉄道の夜"])
    }

    func test空の検索語は全件を返す() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        XCTAssertEqual(catalog.filtered(by: "   ").count, 2)
    }

    func test一致しない検索語は空を返す() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        XCTAssertTrue(catalog.filtered(by: "存在しない作品").isEmpty)
    }

    func test著者ごとにカタログ順を保ってまとめられる() throws {
        let catalog = try AozoraCatalogLoader.decode(Data(Self.sampleJSON.utf8))
        let grouped = catalog.groupedByAuthor
        XCTAssertEqual(grouped.map(\.author), ["芥川竜之介", "宮沢賢治"])
        XCTAssertEqual(grouped.first?.works.count, 1)
    }

    // MARK: - Fixture

    private static let sampleJSON = """
    {
      "version": 1,
      "source": "https://www.aozora.gr.jp/index_pages/list_person_all_extended_utf8.zip",
      "works": [
        {
          "id": "000092",
          "title": "蜘蛛の糸",
          "subtitle": "",
          "author": "芥川竜之介",
          "authorId": "000879",
          "cardURL": "https://www.aozora.gr.jp/cards/000879/card92.html",
          "textZipURL": "https://www.aozora.gr.jp/cards/000879/files/92_ruby_164.zip",
          "encoding": "ShiftJIS"
        },
        {
          "id": "048222",
          "title": "銀河鉄道の夜",
          "subtitle": "初期形三",
          "author": "宮沢賢治",
          "authorId": "000081",
          "cardURL": "https://www.aozora.gr.jp/cards/000081/card48222.html",
          "textZipURL": "https://www.aozora.gr.jp/cards/000081/files/48222_ruby_59603.zip",
          "encoding": "ShiftJIS"
        }
      ]
    }
    """
}
