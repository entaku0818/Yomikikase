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

    // MARK: - MyFilesView.filteredFiles(from:filter:searchText:)（本番実装を直接検証）

    private func makeFile(_ title: String, type: FileItem.FileType) -> FileItem {
        FileItem(id: UUID(), title: title, subtitle: "", date: Date(timeIntervalSince1970: 0), type: type)
    }

    private var sampleFiles: [FileItem] {
        [
            makeFile("Apple Report", type: .pdf),
            makeFile("banana note", type: .text),
            makeFile("Cherry Book", type: .epub),
            makeFile("apple pie recipe", type: .text)
        ]
    }

    func test_filteredFiles_allフィルタ検索空で全件返ること() {
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .all, searchText: "")
        XCTAssertEqual(result.count, 4)
    }

    func test_filteredFiles_pdfフィルタでpdfのみ返ること() {
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .pdf, searchText: "")
        XCTAssertEqual(result.map { $0.title }, ["Apple Report"])
    }

    func test_filteredFiles_textフィルタでtextのみ返ること() {
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .text, searchText: "")
        XCTAssertEqual(Set(result.map { $0.title }), ["banana note", "apple pie recipe"])
    }

    func test_filteredFiles_検索は大文字小文字を無視すること() {
        // "apple" は "Apple Report" と "apple pie recipe" にマッチするはず
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .all, searchText: "APPLE")
        XCTAssertEqual(Set(result.map { $0.title }), ["Apple Report", "apple pie recipe"])
    }

    func test_filteredFiles_フィルタと検索はAND条件であること() {
        // textフィルタ かつ "apple" → "apple pie recipe" のみ（"Apple Report" はpdfなので除外）
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .text, searchText: "apple")
        XCTAssertEqual(result.map { $0.title }, ["apple pie recipe"])
    }

    func test_filteredFiles_ANDのどちらか一方だけ満たしても除外されること() {
        // pdfフィルタ かつ "banana" → 一致なし（bananaはtext、pdfのタイトルにbananaは無い）
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .pdf, searchText: "banana")
        XCTAssertTrue(result.isEmpty)
    }

    func test_filteredFiles_マッチしない検索文字列で空になること() {
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .all, searchText: "zzz")
        XCTAssertTrue(result.isEmpty)
    }

    func test_filteredFiles_検索空はフィルタのみ適用されること() {
        let result = MyFilesView.filteredFiles(from: sampleFiles, filter: .epub, searchText: "")
        XCTAssertEqual(result.map { $0.title }, ["Cherry Book"])
    }

    func test_filteredFiles_空入力は空を返すこと() {
        let result = MyFilesView.filteredFiles(from: [], filter: .all, searchText: "apple")
        XCTAssertTrue(result.isEmpty)
    }
}
