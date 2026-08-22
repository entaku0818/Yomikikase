import XCTest
import ZIPFoundation
@testable import VoiceYourText

/// 青空文庫クライアントのテスト。ネットワークを使わない部分（ZIP展開・出典表記・エラーメッセージ）を対象にする。
final class AozoraClientTests: XCTestCase {

    // MARK: - ZIP展開

    func testZIP内のテキストを取り出してデコードできる() throws {
        let source = "吾輩は猫である\r\n夏目漱石"
        let zip = try Self.makeZip(fileName: "wagahai.txt", contents: source, encoding: .shiftJIS)

        XCTAssertEqual(try AozoraClient.extractText(from: zip), source)
    }

    func testテキスト以外のファイルが混ざっていてもtxtを選ぶ() throws {
        let zip = try Self.makeZip(
            entries: [
                ("readme.html", Data("<html></html>".utf8)),
                ("kokoro.txt", try XCTUnwrap("こころ".data(using: .shiftJIS)))
            ]
        )

        XCTAssertEqual(try AozoraClient.extractText(from: zip), "こころ")
    }

    func testZIPでないデータはinvalidArchiveを投げる() {
        XCTAssertThrowsError(try AozoraClient.extractText(from: Data("not a zip".utf8))) { error in
            XCTAssertEqual(error as? AozoraClientError, .invalidArchive)
        }
    }

    func test空のZIPはinvalidArchiveを投げる() throws {
        let archive = try Archive(accessMode: .create)
        let zip = try XCTUnwrap(archive.data)

        XCTAssertThrowsError(try AozoraClient.extractText(from: zip)) { error in
            XCTAssertEqual(error as? AozoraClientError, .invalidArchive)
        }
    }

    // MARK: - 出典表記

    func test本文の末尾に出典と底本が付く() {
        let document = AozoraTextNormalizer.Document(
            title: "蜘蛛の糸",
            author: "芥川竜之介",
            body: "或日の事でございます。",
            colophon: "底本：「蜘蛛の糸・杜子春」新潮文庫、新潮社"
        )

        let text = AozoraClient.readingText(for: Self.work, document: document)

        XCTAssertTrue(text.hasPrefix("蜘蛛の糸\n芥川竜之介\n\n或日の事でございます。"))
        XCTAssertTrue(text.contains("出典：青空文庫（https://www.aozora.gr.jp/cards/000879/card92.html）"))
        XCTAssertTrue(text.contains("底本：「蜘蛛の糸・杜子春」新潮文庫、新潮社"))
    }

    func test底本が取れなくても出典表記は付く() {
        let document = AozoraTextNormalizer.Document(
            title: "",
            author: "",
            body: "本文",
            colophon: ""
        )

        let text = AozoraClient.readingText(for: Self.work, document: document)

        // タイトル・著者がファイルから取れない場合はカタログの値で補う
        XCTAssertTrue(text.hasPrefix("蜘蛛の糸\n芥川竜之介\n\n本文"))
        XCTAssertTrue(text.hasSuffix("出典：青空文庫（https://www.aozora.gr.jp/cards/000879/card92.html）"))
    }

    // MARK: - エラーメッセージ

    func testオフラインエラーに通信環境を確認する案内が出る() {
        XCTAssertEqual(
            AozoraClientError.offline.errorDescription,
            "インターネットに接続できませんでした。通信環境を確認してもう一度お試しください"
        )
    }

    func test全てのエラーが日本語の説明を持つ() {
        let errors: [AozoraClientError] = [.offline, .serverError, .invalidArchive, .decodingFailed, .emptyContent]
        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "\(error)")
        }
    }

    // MARK: - testValue

    func testテスト用の依存はカタログと本文を返す() async throws {
        let client = AozoraClient.testValue
        let catalog = try await client.loadCatalog()

        XCTAssertEqual(catalog.works.count, 1)

        let text = try await client.downloadText(catalog.works[0])
        XCTAssertEqual(text, "Test aozora content")
    }

    // MARK: - Fixture

    private static let work = AozoraWork(
        id: "000092",
        title: "蜘蛛の糸",
        subtitle: "",
        author: "芥川竜之介",
        authorId: "000879",
        cardURL: URL(string: "https://www.aozora.gr.jp/cards/000879/card92.html")!,
        textZipURL: URL(string: "https://www.aozora.gr.jp/cards/000879/files/92_ruby_164.zip")!,
        encoding: "ShiftJIS"
    )

    private static func makeZip(fileName: String, contents: String, encoding: String.Encoding) throws -> Data {
        let data = try XCTUnwrap(contents.data(using: encoding))
        return try makeZip(entries: [(fileName, data)])
    }

    private static func makeZip(entries: [(String, Data)]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: .deflate,
                provider: { position, size in
                    data.subdata(in: Int(position)..<Int(position) + size)
                }
            )
        }
        return try XCTUnwrap(archive.data)
    }
}
