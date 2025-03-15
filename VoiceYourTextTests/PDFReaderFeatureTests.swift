//
//  File.swift
//  VoiceYourTextTests
//
//  Created by 遠藤拓弥 on 2025/01/21.
//

import XCTest
import ComposableArchitecture
import PDFKit
@testable import VoiceYourText

@MainActor
final class PDFReaderFeatureTests: XCTestCase {

    func testStartReading() async {
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "テストテキスト",
                isReading: false
            )
        ) {
            PDFReaderFeature()
        } withDependencies: { dependencies in
            dependencies.speechSynthesizer = .testValue
        }

        await store.send(.startReading) {
            $0.isReading = true
        }

        await store.receive(.stopReading) {
            $0.isReading = false
        }
    }

    func testStopReading() async {
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "テストテキスト",
                isReading: true
            )
        ) {
            PDFReaderFeature()
        } withDependencies: { dependencies in
            dependencies.speechSynthesizer = .testValue
        }

        await store.send(.stopReading) {
            $0.isReading = false
        }
    }

    func testPDFLoadFailure() async {
        // テスト用の無効なURL
        let invalidURL = URL(fileURLWithPath: "/invalid/path.pdf")
        
        let store = TestStore(
            initialState: PDFReaderFeature.State()
        ) {
            PDFReaderFeature()
        } withDependencies: { dependencies in
            // 無効なPDFドキュメントを返すようにモック
            dependencies.pdfDocumentClient = .testValue(document: nil)
        }

        await store.send(.loadPDF(invalidURL))
        // loadPDFアクションが失敗した場合は何も受信しないことを確認
        // (PDFDocument(url:)がnilを返す場合、アクションは何も送信しない)
    }
}

// PDFDocument初期化のためのクライアント
struct PDFDocumentClient {
    var createDocument: (URL) -> PDFDocument?
}

extension PDFDocumentClient: DependencyKey {
    static var liveValue = Self(
        createDocument: { url in PDFDocument(url: url) }
    )
    
    static func testValue(document: PDFDocument?) -> Self {
        Self(createDocument: { _ in document })
    }
}

extension DependencyValues {
    var pdfDocumentClient: PDFDocumentClient {
        get { self[PDFDocumentClient.self] }
        set { self[PDFDocumentClient.self] = newValue }
    }
}

// テスト用のBundleクライアント
extension DependencyValues {
    var bundle: BundleClient {
        get { self[BundleClient.self] }
        set { self[BundleClient.self] = newValue }
    }
}

struct BundleClient {
    var url: (String, String) -> URL?
}

extension BundleClient: TestDependencyKey {
    static var testValue = Self(
        url: { _, _ in URL(fileURLWithPath: "/test/mock.pdf") }
    )
}

extension BundleClient: DependencyKey {
    static var liveValue = Self(
        url: Bundle.main.url(forResource:withExtension:)
    )
}
