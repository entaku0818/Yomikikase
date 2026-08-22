import Foundation

/// 青空文庫の1作品。`Resources/AozoraCatalog.json` の1要素に対応する。
struct AozoraWork: Codable, Equatable, Identifiable, Sendable {
    /// 青空文庫の作品ID。
    let id: String
    let title: String
    let subtitle: String?
    let author: String
    /// 青空文庫の人物ID。
    let authorId: String
    /// 図書カード（出典表記に使う）。
    let cardURL: URL
    /// 本文テキスト（zip）。
    let textZipURL: URL
    /// CSVのテキストファイル符号化方式。実運用では ShiftJIS。
    let encoding: String?

    /// 副題があれば連結した表示用タイトル。
    var displayTitle: String {
        guard let subtitle, !subtitle.isEmpty else {
            return title
        }
        return "\(title)　\(subtitle)"
    }
}

/// 同梱・差し替え可能な作品カタログ。
struct AozoraCatalog: Codable, Equatable, Sendable {
    let version: Int
    /// カタログの生成元（青空文庫の公開CSV）。
    let source: String
    let works: [AozoraWork]

    static let empty = AozoraCatalog(version: 0, source: "", works: [])

    /// 著者ごとにまとめる。カタログの掲載順を保ったまま著者の初出順に並べる。
    var groupedByAuthor: [(author: String, works: [AozoraWork])] {
        var order: [String] = []
        var buckets: [String: [AozoraWork]] = [:]
        for work in works {
            if buckets[work.author] == nil {
                order.append(work.author)
            }
            buckets[work.author, default: []].append(work)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    /// タイトル・著者の部分一致で絞り込む。空文字は全件。
    func filtered(by query: String) -> [AozoraWork] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return works
        }
        return works.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(keyword)
                || $0.author.localizedCaseInsensitiveContains(keyword)
        }
    }
}

/// 作品カタログの読み込み。
///
/// 掲載作品をコードに直書きせず JSON に持たせてある。
/// Documents 配下に同名ファイルを置けばそちらが優先されるので、
/// アプリを更新しなくても差し替えられる。
/// JSON自体は `iOS/scripts/generate_aozora_catalog.py` で青空文庫の公開CSVから生成する。
enum AozoraCatalogLoader {

    static let fileName = "AozoraCatalog"
    static let fileExtension = "json"

    enum LoadError: Error, LocalizedError {
        case notFound
        case malformed

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "作品リストが見つかりませんでした"
            case .malformed:
                return "作品リストの形式が不正です"
            }
        }
    }

    /// アプリ本体のバンドル。テストはアプリをホストに動くのでこの参照で共通化できる。
    static var bundle: Bundle { Bundle(for: BundleMarker.self) }

    /// 差し替え用ファイルの置き場所。
    static var overrideURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("\(fileName).\(fileExtension)")
    }

    static func decode(_ data: Data) throws -> AozoraCatalog {
        do {
            return try JSONDecoder().decode(AozoraCatalog.self, from: data)
        } catch {
            throw LoadError.malformed
        }
    }

    /// Documents の差し替えファイル → アプリ同梱JSON の順に読む。
    static func load() throws -> AozoraCatalog {
        if let overrideURL, FileManager.default.fileExists(atPath: overrideURL.path),
           let data = try? Data(contentsOf: overrideURL) {
            // 差し替えファイルが壊れていても同梱版で復帰できるようにする。
            if let catalog = try? decode(data), !catalog.works.isEmpty {
                return catalog
            }
        }
        guard let url = bundle.url(forResource: fileName, withExtension: fileExtension) else {
            throw LoadError.notFound
        }
        return try decode(try Data(contentsOf: url))
    }
}

/// `Bundle(for:)` 用のマーカー。
private final class BundleMarker {}
