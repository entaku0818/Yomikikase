//
//  WebPageFetchClientTests.swift
//  VoiceYourTextTests
//

import XCTest
import Dependencies
@testable import VoiceYourText

final class WebPageFetchClientTests: XCTestCase {

    // MARK: - testValue

    func test_testValueは固定文字列を返す() async throws {
        let client = WebPageFetchClient.testValue
        let result = try await client.fetchText(URL(string: "https://example.com")!)
        XCTAssertEqual(result, "Test web page content")
    }

    // MARK: - URL バリデーション (liveValue)

    func test_httpURLはエラーになる() async {
        let client = WebPageFetchClient.liveValue
        let url = URL(string: "http://example.com")!
        do {
            _ = try await client.fetchText(url)
            XCTFail("httpsRequired エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .httpsRequired)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    func test_ftpURLはエラーになる() async {
        let client = WebPageFetchClient.liveValue
        let url = URL(string: "ftp://example.com/file.txt")!
        do {
            _ = try await client.fetchText(url)
            XCTFail("httpsRequired エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .httpsRequired)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    // MARK: - エラー LocalizedDescription

    func test_httpsRequiredのエラーメッセージが正しい() {
        let error = WebPageFetchError.httpsRequired
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_serverErrorのエラーメッセージが正しい() {
        let error = WebPageFetchError.serverError
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_encodingErrorのエラーメッセージが正しい() {
        let error = WebPageFetchError.encodingError
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_emptyContentのエラーメッセージが正しい() {
        let error = WebPageFetchError.emptyContent
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }
}

// MARK: - Equatable conformance for testing
extension WebPageFetchError: Equatable {
    public static func == (lhs: WebPageFetchError, rhs: WebPageFetchError) -> Bool {
        switch (lhs, rhs) {
        case (.httpsRequired, .httpsRequired),
             (.serverError, .serverError),
             (.encodingError, .encodingError),
             (.emptyContent, .emptyContent):
            return true
        default:
            return false
        }
    }
}
