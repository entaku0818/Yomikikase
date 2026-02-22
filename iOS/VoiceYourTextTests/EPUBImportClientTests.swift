//
//  EPUBImportClientTests.swift
//  VoiceYourTextTests
//

import XCTest
import Dependencies
@testable import VoiceYourText

final class EPUBImportClientTests: XCTestCase {

    // MARK: - testValue

    func test_testValueは固定文字列を返す() async throws {
        let client = EPUBImportClient.testValue
        let result = try await client.extractText(URL(fileURLWithPath: "/dummy.epub"))
        XCTAssertEqual(result, "Test EPUB content")
    }

    // MARK: - EPUBError LocalizedDescription

    func test_invalidEPUBのエラーメッセージが正しい() {
        let error = EPUBTextExtractor.EPUBError.invalidEPUB
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_containerNotFoundのエラーメッセージが正しい() {
        let error = EPUBTextExtractor.EPUBError.containerNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_opfNotFoundのエラーメッセージが正しい() {
        let error = EPUBTextExtractor.EPUBError.opfNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_noContentのエラーメッセージが正しい() {
        let error = EPUBTextExtractor.EPUBError.noContent
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    // MARK: - 存在しないファイルはエラーになる

    func test_存在しないEPUBはエラーになる() async {
        let client = EPUBImportClient.liveValue
        let url = URL(fileURLWithPath: "/nonexistent/path.epub")
        do {
            _ = try await client.extractText(url)
            XCTFail("エラーが発生するべき")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
