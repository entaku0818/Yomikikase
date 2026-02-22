import Foundation
import Dependencies

struct WebPageFetchClient {
    var fetchText: @Sendable (URL) async throws -> String
}

extension WebPageFetchClient: DependencyKey {
    static let liveValue = Self(
        fetchText: { url in
            guard url.scheme?.lowercased() == "https" else {
                throw WebPageFetchError.httpsRequired
            }

            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw WebPageFetchError.serverError
            }

            // Detect encoding from Content-Type header
            let html: String
            if let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type"),
               let charsetRange = contentType.range(of: "charset=", options: .caseInsensitive) {
                let charsetString = String(contentType[charsetRange.upperBound...])
                    .components(separatedBy: ";").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charsetString as CFString)
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                let encoding = String.Encoding(rawValue: nsEncoding)
                if let str = String(data: data, encoding: encoding) {
                    html = str
                } else {
                    html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                }
            } else if let utf8 = String(data: data, encoding: .utf8) {
                html = utf8
            } else if let latin1 = String(data: data, encoding: .isoLatin1) {
                html = latin1
            } else {
                throw WebPageFetchError.encodingError
            }

            guard !html.isEmpty else {
                throw WebPageFetchError.emptyContent
            }

            return HTMLTextExtractor.extract(from: html)
        }
    )

    static let testValue = Self(
        fetchText: { _ in "Test web page content" }
    )
}

extension DependencyValues {
    var webPageFetch: WebPageFetchClient {
        get { self[WebPageFetchClient.self] }
        set { self[WebPageFetchClient.self] = newValue }
    }
}

enum WebPageFetchError: Error, LocalizedError {
    case httpsRequired
    case serverError
    case encodingError
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .httpsRequired:
            return "https://で始まるURLを入力してください"
        case .serverError:
            return "ページの取得に失敗しました"
        case .encodingError:
            return "ページのエンコーディングを判別できませんでした"
        case .emptyContent:
            return "ページのコンテンツを取得できませんでした"
        }
    }
}
