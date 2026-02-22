import Foundation
import Dependencies
import UniformTypeIdentifiers

struct EPUBImportClient {
    var extractText: @Sendable (URL) async throws -> String
}

extension EPUBImportClient: DependencyKey {
    static let liveValue = Self(
        extractText: { url in
            let isSecured = url.startAccessingSecurityScopedResource()
            defer {
                if isSecured { url.stopAccessingSecurityScopedResource() }
            }
            return try EPUBTextExtractor.extract(from: url)
        }
    )

    static let testValue = Self(
        extractText: { _ in "Test EPUB content" }
    )
}

extension DependencyValues {
    var epubImport: EPUBImportClient {
        get { self[EPUBImportClient.self] }
        set { self[EPUBImportClient.self] = newValue }
    }
}
