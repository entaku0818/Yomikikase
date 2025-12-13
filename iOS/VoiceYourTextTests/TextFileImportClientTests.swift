//
//  TextFileImportClientTests.swift
//  VoiceYourTextTests
//
//  Created by Claude on 2025/12/13.
//

import XCTest
import Dependencies
@testable import VoiceYourText

final class TextFileImportClientTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - UTF-8 エンコーディングテスト

    func test_UTF8ファイルを正常に読み込める() async throws {
        // Given
        let content = "Hello, World!\nこんにちは世界"
        let fileURL = tempDirectory.appendingPathComponent("test_utf8.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let client = TextFileImportClient.liveValue
        let result = try await client.readTextFile(fileURL)

        // Then
        XCTAssertEqual(result, content)
    }

    func test_空のファイルを読み込める() async throws {
        // Given
        let content = ""
        let fileURL = tempDirectory.appendingPathComponent("test_empty.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let client = TextFileImportClient.liveValue
        let result = try await client.readTextFile(fileURL)

        // Then
        XCTAssertEqual(result, "")
    }

    func test_日本語テキストを正常に読み込める() async throws {
        // Given
        let content = "吾輩は猫である。名前はまだ無い。\nどこで生れたかとんと見当がつかぬ。"
        let fileURL = tempDirectory.appendingPathComponent("test_japanese.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let client = TextFileImportClient.liveValue
        let result = try await client.readTextFile(fileURL)

        // Then
        XCTAssertEqual(result, content)
    }

    func test_複数行のテキストを正常に読み込める() async throws {
        // Given
        let content = """
        1行目
        2行目
        3行目

        5行目（4行目は空行）
        """
        let fileURL = tempDirectory.appendingPathComponent("test_multiline.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let client = TextFileImportClient.liveValue
        let result = try await client.readTextFile(fileURL)

        // Then
        XCTAssertEqual(result, content)
    }

    // MARK: - Shift-JIS エンコーディングテスト

    func test_ShiftJISファイルを正常に読み込める() async throws {
        // Given
        let content = "こんにちは世界"
        let fileURL = tempDirectory.appendingPathComponent("test_shiftjis.txt")
        let shiftJISData = content.data(using: .shiftJIS)!
        try shiftJISData.write(to: fileURL)

        // When
        let client = TextFileImportClient.liveValue
        let result = try await client.readTextFile(fileURL)

        // Then
        XCTAssertEqual(result, content)
    }

    // MARK: - エラーケーステスト

    func test_存在しないファイルを読み込むとエラー() async {
        // Given
        let fileURL = tempDirectory.appendingPathComponent("nonexistent.txt")

        // When/Then
        let client = TextFileImportClient.liveValue
        do {
            _ = try await client.readTextFile(fileURL)
            XCTFail("エラーが発生するべき")
        } catch {
            // エラーが発生することを確認
            XCTAssertNotNil(error)
        }
    }

    // MARK: - testValue テスト

    func test_testValueはテスト用の固定値を返す() async throws {
        // When
        let client = TextFileImportClient.testValue
        let result = try await client.readTextFile(URL(fileURLWithPath: "/dummy"))

        // Then
        XCTAssertEqual(result, "Test content")
    }

    // MARK: - 長いテキストテスト

    func test_長いテキストを正常に読み込める() async throws {
        // Given
        let content = String(repeating: "あいうえおかきくけこ", count: 1000)
        let fileURL = tempDirectory.appendingPathComponent("test_long.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // When
        let client = TextFileImportClient.liveValue
        let result = try await client.readTextFile(fileURL)

        // Then
        XCTAssertEqual(result.count, content.count)
        XCTAssertEqual(result, content)
    }
}
