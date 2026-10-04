import Foundation
import ComposableArchitecture
import PDFKit
import UniformTypeIdentifiers

struct TextFileImportClient {
    var readTextFile: @Sendable (URL) async throws -> String
    /// テキスト・Markdown・PDF を読む。Google ドライブなど「ファイル」アプリの場所から選んだファイルに使う
    var readDocument: @Sendable (URL) async throws -> String
}

extension TextFileImportClient {
    /// 「Gドライブ」ボタンの選択画面で選べる種類。
    /// ドライブ全体を読む OAuth 権限（drive.readonly）は Google の審査が要るので使わず、
    /// 「ファイル」アプリのドライブ（Google ドライブアプリが入っていれば出る）から利用者が選んだファイルだけを読む
    static let documentTypes: [UTType] = [.plainText, .utf8PlainText, .pdf]
        + [UTType(filenameExtension: "md"), UTType("net.daringfireball.markdown")].compactMap { $0 }

    /// テキストファイルを読む（UTF-8 → Shift-JIS → EUC-JP の順に試す）
    static func readText(at url: URL) throws -> String {
        // Security Scoped Resource へのアクセス許可
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)

        // UTF-8を最初に試し、失敗したらShift-JISを試す
        if let content = String(data: data, encoding: .utf8) {
            return content
        } else if let content = String(data: data, encoding: .shiftJIS) {
            return content
        } else if let content = String(data: data, encoding: .japaneseEUC) {
            return content
        } else {
            throw TextFileImportError.unsupportedEncoding
        }
    }

    /// PDF の本文。文字が無い（画像だけの）PDF は空文字
    static func pdfText(at url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else { throw TextFileImportError.fileReadError }
        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension TextFileImportClient: DependencyKey {
    static let liveValue = Self(
        readTextFile: { url in
            try readText(at: url)
        },
        readDocument: { url in
            let isPDF = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .pdf)
                ?? (url.pathExtension.lowercased() == "pdf")
            guard isPDF else {
                return try readText(at: url)
            }
            let isSecured = url.startAccessingSecurityScopedResource()
            defer {
                if isSecured {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let text = try pdfText(at: url)
            guard !text.isEmpty else { throw TextFileImportError.noText }
            return text
        }
    )

    static let testValue = Self(
        readTextFile: { _ in
            "Test content"
        },
        readDocument: { _ in
            "Test content"
        }
    )
}

extension DependencyValues {
    var textFileImport: TextFileImportClient {
        get { self[TextFileImportClient.self] }
        set { self[TextFileImportClient.self] = newValue }
    }
}

enum TextFileImportError: Error, LocalizedError {
    case unsupportedEncoding
    case fileReadError
    case noText

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            return "ファイルのエンコーディングがサポートされていません"
        case .fileReadError:
            return "ファイルの読み込みに失敗しました"
        case .noText:
            return "このファイルには読み上げられる文字がありません"
        }
    }
}
