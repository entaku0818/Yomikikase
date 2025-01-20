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
    func testLoadPDFSuccess() async {
        // テスト用のPDFドキュメントを作成
        let testPDFDocument = PDFDocument()
        let page = PDFPage()
        testPDFDocument.insert(page, at: 0)

        let store = TestStore(
            initialState: PDFReaderFeature.State()
        ) {
            PDFReaderFeature()
        } withDependencies: { dependencies in
            // Bundle.main.urlをモック
            dependencies.bundle.url = { _, _ in
                URL(fileURLWithPath: "/test/sample.pdf")
            }
        }

        // PDFDocument初期化をモック
        // 実際のテストでは適切なモック方法を実装する必要があります

        await store.send(.loadPDF)
        await store.receive(.pdfLoaded(testPDFDocument)) {
            $0.pdfDocument = testPDFDocument
        }
        await store.receive(.extractTextCompleted("")) {
            $0.pdfText = ""
        }
    }

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
        let store = TestStore(
            initialState: PDFReaderFeature.State()
        ) {
            PDFReaderFeature()
        } withDependencies: { dependencies in
            // 無効なURLを返すようにモック
            dependencies.bundle.url = { _, _ in nil }
        }

        await store.send(.loadPDF)
        // エラー処理の検証をここに追加
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
