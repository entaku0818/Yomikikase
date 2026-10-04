//
//  TextFileImportClientTests.swift
//  VoiceYourTextTests
//

import UIKit
import XCTest
@testable import VoiceYourText

final class TextFileImportClientTests: XCTestCase {
    private var tempURLs: [URL] = []

    override func tearDown() {
        tempURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    private func tempURL(_ ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        tempURLs.append(url)
        return url
    }

    func testReadDocumentReadsShiftJISText() async throws {
        let url = tempURL("txt")
        try XCTUnwrap("ドライブのメモ".data(using: .shiftJIS)).write(to: url)
        let text = try await TextFileImportClient.liveValue.readDocument(url)
        XCTAssertEqual(text, "ドライブのメモ")
    }

    func testReadDocumentExtractsPDFText() async throws {
        let url = tempURL("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            ("Hello Drive" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
        let text = try await TextFileImportClient.liveValue.readDocument(url)
        XCTAssertEqual(text, "Hello Drive")
    }

    func testReadDocumentRejectsPDFWithoutText() async throws {
        let url = tempURL("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
        }
        do {
            _ = try await TextFileImportClient.liveValue.readDocument(url)
            XCTFail("文字の無い PDF はエラーにする")
        } catch let error as TextFileImportError {
            XCTAssertEqual(error, .noText)
        }
    }

    func testDocumentTypesIncludePDFAndMarkdown() {
        XCTAssertTrue(TextFileImportClient.documentTypes.contains(.pdf))
        XCTAssertTrue(TextFileImportClient.documentTypes.contains { $0.preferredFilenameExtension == "md" })
    }
}
