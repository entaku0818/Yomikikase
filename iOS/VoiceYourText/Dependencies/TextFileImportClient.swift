import Foundation
import ComposableArchitecture
import UniformTypeIdentifiers

struct TextFileImportClient {
    var readTextFile: @Sendable (URL) async throws -> String
}

extension TextFileImportClient: DependencyKey {
    static let liveValue = Self(
        readTextFile: { url in
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
    )

    static let testValue = Self(
        readTextFile: { _ in
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

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            return "ファイルのエンコーディングがサポートされていません"
        case .fileReadError:
            return "ファイルの読み込みに失敗しました"
        }
    }
}
