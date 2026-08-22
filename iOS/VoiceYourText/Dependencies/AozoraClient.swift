import Foundation
import Dependencies
import ZIPFoundation

/// 青空文庫の作品を取得するクライアント。
///
/// 取得経路は青空文庫が公開している配布ファイル（図書カードからリンクされている
/// テキストZIP）のみを使う。HTMLのスクレイピングはしない。
struct AozoraClient {
    /// 同梱（または差し替え）の作品カタログを読む。
    var loadCatalog: @Sendable () async throws -> AozoraCatalog
    /// 作品本文をダウンロードし、読み上げ用に正規化したテキストを返す。
    var downloadText: @Sendable (AozoraWork) async throws -> String
}

enum AozoraClientError: Error, LocalizedError, Equatable {
    case offline
    case serverError
    case invalidArchive
    case decodingFailed
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .offline:
            return "インターネットに接続できませんでした。通信環境を確認してもう一度お試しください"
        case .serverError:
            return "青空文庫から作品を取得できませんでした。しばらくしてからお試しください"
        case .invalidArchive:
            return "作品ファイルを展開できませんでした"
        case .decodingFailed:
            return "作品ファイルの文字コードを判別できませんでした"
        case .emptyContent:
            return "作品の本文を取得できませんでした"
        }
    }
}

extension AozoraClient: DependencyKey {
    static let liveValue = Self(
        loadCatalog: {
            try AozoraCatalogLoader.load()
        },
        downloadText: { work in
            let data = try await fetchZipData(from: work.textZipURL)
            let raw = try extractText(from: data)
            let document = AozoraTextNormalizer.normalize(raw)
            guard !document.body.isEmpty else {
                throw AozoraClientError.emptyContent
            }
            return readingText(for: work, document: document)
        }
    )

    static let testValue = Self(
        loadCatalog: {
            AozoraCatalog(
                version: 1,
                source: "test",
                works: [
                    AozoraWork(
                        id: "92",
                        title: "蜘蛛の糸",
                        subtitle: "",
                        author: "芥川竜之介",
                        authorId: "000879",
                        cardURL: sampleURL("https://www.aozora.gr.jp/cards/000879/card92.html"),
                        textZipURL: sampleURL("https://www.aozora.gr.jp/cards/000879/files/92_ruby_164.zip"),
                        encoding: "ShiftJIS"
                    )
                ]
            )
        },
        downloadText: { _ in "Test aozora content" }
    )

    /// testValue のフィクスチャ用。定数文字列しか渡さないので失敗しない。
    private static func sampleURL(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }

    // MARK: - Live helpers

    /// テキストZIPをダウンロードする。オフラインとサーバーエラーを区別して投げる。
    static func fetchZipData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut:
                throw AozoraClientError.offline
            default:
                throw AozoraClientError.serverError
            }
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AozoraClientError.serverError
        }
        return data
    }

    /// ZIP内の .txt を取り出して文字列にデコードする。
    static func extractText(from zipData: Data) throws -> String {
        let archive: Archive
        do {
            archive = try Archive(data: zipData, accessMode: .read)
        } catch {
            throw AozoraClientError.invalidArchive
        }

        // 青空文庫のZIPは .txt 1本だけだが、ファイル名が読めなかった場合に備えて先頭ファイルへ落とす。
        let entries = archive.filter { $0.type == .file }
        guard let entry = entries.first(where: { $0.path.lowercased().hasSuffix(".txt") }) ?? entries.first else {
            throw AozoraClientError.invalidArchive
        }

        var textData = Data()
        do {
            _ = try archive.extract(entry) { textData.append($0) }
        } catch {
            throw AozoraClientError.invalidArchive
        }

        guard let text = AozoraTextNormalizer.decode(textData) else {
            throw AozoraClientError.decodingFailed
        }
        return text
    }

    /// 本文の末尾に出典表記（青空文庫・図書カード・底本）を付ける。
    static func readingText(for work: AozoraWork, document: AozoraTextNormalizer.Document) -> String {
        var parts: [String] = []
        let title = document.title.isEmpty ? work.displayTitle : document.title
        let author = document.author.isEmpty ? work.author : document.author
        parts.append("\(title)\n\(author)")
        parts.append(document.body)

        var credit = "出典：青空文庫（\(work.cardURL.absoluteString)）"
        if !document.colophon.isEmpty {
            credit += "\n\(document.colophon)"
        }
        parts.append(credit)

        return parts.joined(separator: "\n\n")
    }
}

extension DependencyValues {
    var aozora: AozoraClient {
        get { self[AozoraClient.self] }
        set { self[AozoraClient.self] = newValue }
    }
}
