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

    // MARK: - 不正なファイル内容

    func test_ZIPでないファイルはエラーになる() async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".epub")
        try? "not a zip file content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = EPUBImportClient.liveValue
        do {
            _ = try await client.extractText(tempURL)
            XCTFail("エラーが発生するべき")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_空ファイルはエラーになる() async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".epub")
        try? Data().write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = EPUBImportClient.liveValue
        do {
            _ = try await client.extractText(tempURL)
            XCTFail("エラーが発生するべき")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - EPUBError の網羅

    func test_全EPUBエラーのerrorDescriptionが非空() {
        let errors: [EPUBTextExtractor.EPUBError] = [
            .invalidEPUB, .containerNotFound, .opfNotFound, .noContent
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) の errorDescription が nil")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) の errorDescription が空")
        }
    }

    func test_EPUBErrorは異なるケースで異なるメッセージを持つ() {
        let messages = [
            EPUBTextExtractor.EPUBError.invalidEPUB.errorDescription!,
            EPUBTextExtractor.EPUBError.containerNotFound.errorDescription!,
            EPUBTextExtractor.EPUBError.opfNotFound.errorDescription!,
            EPUBTextExtractor.EPUBError.noContent.errorDescription!,
        ]
        // 各エラーメッセージが重複していない
        XCTAssertEqual(Set(messages).count, messages.count)
    }
}
