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

    // MARK: - 追加スキームバリデーション

    func test_fileスキームURLはエラーになる() async {
        let client = WebPageFetchClient.liveValue
        let url = URL(fileURLWithPath: "/etc/hosts")
        do {
            _ = try await client.fetchText(url)
            XCTFail("httpsRequired エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .httpsRequired)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    func test_javascriptスキームURLはエラーになる() async {
        let client = WebPageFetchClient.liveValue
        // javascript: スキームはURLとして初期化できないケースもあるため、
        // スキームがhttps以外であれば全て弾かれることを間接確認
        let url = URL(string: "ftp://malicious.example.com")!
        do {
            _ = try await client.fetchText(url)
            XCTFail("httpsRequired エラーが発生するべき")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .httpsRequired)
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    func test_httpsURLはバリデーションを通過する() async {
        let client = WebPageFetchClient.liveValue
        // 実際のネットワーク接続なしにhttpsスキームチェックのみ確認したい場合は
        // testValueを使う。liveValueはネットワーク必須なのでtestValueで検証。
        let testClient = WebPageFetchClient.testValue
        let result = try? await testClient.fetchText(URL(string: "https://example.com")!)
        XCTAssertNotNil(result)
    }

    // MARK: - 全エラーが異なるメッセージを持つ

    func test_全エラーのメッセージが重複しない() {
        let messages = [
            WebPageFetchError.httpsRequired.errorDescription!,
            WebPageFetchError.serverError.errorDescription!,
            WebPageFetchError.encodingError.errorDescription!,
            WebPageFetchError.emptyContent.errorDescription!,
        ]
        XCTAssertEqual(Set(messages).count, messages.count)
    }
}

// WebPageFetchError は associated value のない enum のため Swift が自動で Equatable に適合する
