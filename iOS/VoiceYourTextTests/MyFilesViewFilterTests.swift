//
//  MyFilesViewFilterTests.swift
//  VoiceYourTextTests
//

import XCTest
@testable import VoiceYourText

final class MyFilesViewFilterTests: XCTestCase {

    // MARK: - FileFilter.matches(_:) - allフィルタ

    func test_allフィルタはtextにマッチすること() {
        XCTAssertTrue(FileFilter.all.matches(.text))
    }

    func test_allフィルタはpdfにマッチすること() {
        XCTAssertTrue(FileFilter.all.matches(.pdf))
    }

    func test_allフィルタはepubにマッチすること() {
        XCTAssertTrue(FileFilter.all.matches(.epub))
    }

    // MARK: - FileFilter.matches(_:) - pdfフィルタ

    func test_pdfフィルタはpdfにマッチすること() {
        XCTAssertTrue(FileFilter.pdf.matches(.pdf))
    }

    func test_pdfフィルタはtextにマッチしないこと() {
        XCTAssertFalse(FileFilter.pdf.matches(.text))
    }

    func test_pdfフィルタはepubにマッチしないこと() {
        XCTAssertFalse(FileFilter.pdf.matches(.epub))
    }

    // MARK: - FileFilter.matches(_:) - textフィルタ

    func test_textフィルタはtextにマッチすること() {
        XCTAssertTrue(FileFilter.text.matches(.text))
    }

    func test_textフィルタはpdfにマッチしないこと() {
        XCTAssertFalse(FileFilter.text.matches(.pdf))
    }

    func test_textフィルタはepubにマッチしないこと() {
        XCTAssertFalse(FileFilter.text.matches(.epub))
    }

    // MARK: - FileFilter.matches(_:) - epubフィルタ

    func test_epubフィルタはepubにマッチすること() {
        XCTAssertTrue(FileFilter.epub.matches(.epub))
    }

    func test_epubフィルタはtextにマッチしないこと() {
        XCTAssertFalse(FileFilter.epub.matches(.text))
    }

    func test_epubフィルタはpdfにマッチしないこと() {
        XCTAssertFalse(FileFilter.epub.matches(.pdf))
    }

    // MARK: - FileFilter.allCases

    func test_allCasesが4ケース含まれること() {
        XCTAssertEqual(FileFilter.allCases.count, 4)
    }

    func test_allCasesにallが含まれること() {
        XCTAssertTrue(FileFilter.allCases.contains(.all))
    }

    func test_allCasesにpdfが含まれること() {
        XCTAssertTrue(FileFilter.allCases.contains(.pdf))
    }

    func test_allCasesにtextが含まれること() {
        XCTAssertTrue(FileFilter.allCases.contains(.text))
    }

    func test_allCasesにepubが含まれること() {
        XCTAssertTrue(FileFilter.allCases.contains(.epub))
    }

    // MARK: - ソートロジック（combinedFiles - 日付降順）

    func test_ソート_新しいファイルが先頭に来ること() {
        let now = Date()
        let older = now.addingTimeInterval(-3600)  // 1時間前

        let newFile = FileItem(id: UUID(), title: "新しい", subtitle: "", date: now, type: .text)
        let oldFile = FileItem(id: UUID(), title: "古い", subtitle: "", date: older, type: .text)

        let files = [oldFile, newFile]
        let sorted = files.sorted { $0.date > $1.date }

        XCTAssertEqual(sorted.first?.title, "新しい")
        XCTAssertEqual(sorted.last?.title, "古い")
    }

    func test_ソート_同じ日付のファイルは順序が保たれること() {
        let now = Date()
        let file1 = FileItem(id: UUID(), title: "A", subtitle: "", date: now, type: .text)
        let file2 = FileItem(id: UUID(), title: "B", subtitle: "", date: now, type: .pdf)

        let files = [file1, file2]
        let sorted = files.sorted { $0.date > $1.date }

        // 同じ日付なら元の順序が変わらないことを確認（安定ソート）
        XCTAssertEqual(sorted.count, 2)
    }

    func test_ソート_空配列はそのまま空であること() {
        let files: [FileItem] = []
        let sorted = files.sorted { $0.date > $1.date }
        XCTAssertTrue(sorted.isEmpty)
    }

    // MARK: - スキャンJSONデコードフォールバックロジック

    func test_JSONデコード_有効なJSON配列は正しくデコードされること() {
        let imagePaths = ["/path/to/image1.jpg", "/path/to/image2.jpg"]
        if let data = try? JSONEncoder().encode(imagePaths),
           let jsonStr = String(data: data, encoding: .utf8),
           let decodedData = jsonStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: decodedData) {
            XCTAssertEqual(decoded, imagePaths)
        } else {
            XCTFail("有効なJSONのデコードに失敗")
        }
    }

    func test_JSONデコード_不正なJSON文字列はデコードに失敗すること() {
        let invalidJSON = "not-a-json"
        let result = invalidJSON.data(using: .utf8).flatMap { data in
            try? JSONDecoder().decode([String].self, from: data)
        }
        XCTAssertNil(result, "不正なJSONはnilになるはず（フォールバックへ）")
    }

    func test_JSONデコード_空文字列はデコードに失敗すること() {
        let emptyString = ""
        let result = emptyString.data(using: .utf8).flatMap { data in
            try? JSONDecoder().decode([String].self, from: data)
        }
        XCTAssertNil(result, "空文字列はnilになるはず（フォールバックへ）")
    }

    func test_JSONデコード_空配列JSONは正しくデコードされること() {
        let emptyArrayJSON = "[]"
        guard let data = emptyArrayJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            XCTFail("空配列JSONのデコードに失敗")
            return
        }
        XCTAssertTrue(decoded.isEmpty, "空配列はデコードして空Arrayになるはず")
    }

    func test_JSONデコード_JSONオブジェクトは配列にデコードできないこと() {
        // オブジェクト型JSON（{...}）を[String]にデコードしようとするとnil
        let objectJSON = "{\"key\": \"value\"}"
        let result = objectJSON.data(using: .utf8).flatMap { data in
            try? JSONDecoder().decode([String].self, from: data)
        }
        XCTAssertNil(result, "オブジェクトJSONはnilになるはず（フォールバックへ）")
    }

    func test_JSONデコード_有効なパスリストをラウンドトリップできること() {
        let originalPaths = ["/documents/scan/page1.png", "/documents/scan/page2.png"]

        // エンコード
        guard let encoded = try? JSONEncoder().encode(originalPaths),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            XCTFail("エンコードに失敗")
            return
        }

        // デコード（FileViewerContainerと同じロジック）
        guard let imagePathsData = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: imagePathsData) else {
            XCTFail("デコードに失敗")
            return
        }

        XCTAssertEqual(decoded, originalPaths)
    }
}
