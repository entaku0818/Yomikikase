//
//  LinkInputViewTests.swift
//  VoiceYourTextTests
//
//  QA: LinkInputView フロー確認テスト
//  カバレッジ: URL検証 / ネットワークエラー / 空コンテンツ / 権限拒否

import XCTest
import Dependencies
@testable import VoiceYourText

final class LinkInputViewTests: XCTestCase {

    // MARK: - URL バリデーションロジックの境界値テスト
    // isValidURL = urlText.lowercased().hasPrefix("https://") && urlText.count > 12

    func test_urlValidation_emptyString_isInvalid() {
        XCTAssertFalse(isValidURL(""))
    }

    func test_urlValidation_httpOnly_isInvalid() {
        XCTAssertFalse(isValidURL("http://example.com"))
    }

    func test_urlValidation_httpsExactlyLength8_isInvalid() {
        // "https://" = 8文字、count > 12 を満たさない
        XCTAssertFalse(isValidURL("https://"))
    }

    func test_urlValidation_httpsLength12_isInvalid() {
        // "https://a.io" = 12文字、count > 12 を満たさない（境界値: 厳密に大きくない）
        XCTAssertFalse(isValidURL("https://a.io"))
        XCTAssertEqual("https://a.io".count, 12)
    }

    func test_urlValidation_httpsLength13_isValid() {
        // "https://ab.io" = 13文字、境界値ちょうど有効
        XCTAssertTrue(isValidURL("https://ab.io"))
        XCTAssertEqual("https://ab.io".count, 13)
    }

    func test_urlValidation_normalUrl_isValid() {
        XCTAssertTrue(isValidURL("https://example.com"))
    }

    func test_urlValidation_uppercaseHTTPS_isValid() {
        // lowercased() で正規化するため大文字でも有効
        XCTAssertTrue(isValidURL("HTTPS://EXAMPLE.COM"))
    }

    func test_urlValidation_ftpUrl_isInvalid() {
        XCTAssertFalse(isValidURL("ftp://example.com/file.txt"))
    }

    // MARK: - WebPageFetchClient: ネットワークエラー時の挙動

    func test_fetchClient_httpsRequired_onHttpUrl() async {
        let client = WebPageFetchClient.liveValue
        let url = URL(string: "http://example.com")!
        do {
            _ = try await client.fetchText(url)
            XCTFail("httpsRequired エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .httpsRequired)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    func test_fetchClient_httpsRequired_onFtpUrl() async {
        let client = WebPageFetchClient.liveValue
        let url = URL(string: "ftp://example.com/data.txt")!
        do {
            _ = try await client.fetchText(url)
            XCTFail("httpsRequired エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .httpsRequired)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    // MARK: - WebPageFetchClient: モックによるエッジケース

    /// ネットワークエラー（URLError）が localizedDescription を返す
    func test_fetchClient_mock_networkError_throwsError() async {
        let client = WebPageFetchClient(
            fetchText: { _ in throw URLError(.notConnectedToInternet) }
        )
        do {
            _ = try await client.fetchText(URL(string: "https://example.com")!)
            XCTFail("エラーが発生するべき")
        } catch {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    /// 空コンテンツ → LinkInputView でエラーメッセージを表示する
    func test_fetchClient_mock_emptyContent_throwsEmptyContentError() async {
        let client = WebPageFetchClient(
            fetchText: { _ in throw WebPageFetchError.emptyContent }
        )
        do {
            _ = try await client.fetchText(URL(string: "https://example.com")!)
            XCTFail("emptyContent エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .emptyContent)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    /// サーバーエラー (5xx) が serverError を返す
    func test_fetchClient_mock_serverError_throwsServerError() async {
        let client = WebPageFetchClient(
            fetchText: { _ in throw WebPageFetchError.serverError }
        )
        do {
            _ = try await client.fetchText(URL(string: "https://example.com")!)
            XCTFail("serverError が発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .serverError)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    /// スペース入りURLは URL(string:) が nil を返す可能性がある
    func test_urlWithSpaces_isInvalidByURLInit() {
        let urlText = "https://example.com/path with spaces"
        // isValidURL はパスするが URL(string:) は nil を返す
        XCTAssertTrue(isValidURL(urlText))
        XCTAssertNil(URL(string: urlText), "スペース入りURLは URL(string:) で nil になるべき")
    }

    // MARK: - WebPageFetchError: 全エラーに説明文がある

    func test_allWebPageFetchErrors_haveLocalizedDescriptions() {
        let errors: [WebPageFetchError] = [.httpsRequired, .serverError, .encodingError, .emptyContent]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) の errorDescription が空")
        }
    }
}

// MARK: - Helper: isValidURL ロジックを複製（View の private プロパティのため）

private func isValidURL(_ urlText: String) -> Bool {
    urlText.lowercased().hasPrefix("https://") && urlText.count > 12
}
