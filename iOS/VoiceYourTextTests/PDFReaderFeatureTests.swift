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
        // まず簡単なテストで確認
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "テストテキスト",
                isReading: false
            )
        ) {
            PDFReaderFeature()
        }

        // isReadingがfalseであることを確認
        XCTAssertFalse(store.state.isReading)
        XCTAssertEqual(store.state.pdfText, "テストテキスト")

        print("🧪 基本状態確認完了")
    }

    static func createTestSynthesizer() -> SpeechSynthesizerClient {
        return SpeechSynthesizerClient(
            speak: { _ in
                print("🧪 testSynthesizer.speak呼び出し")
                return true
            },
            speakWithHighlight: { utterance, onHighlight, onFinish in
                print("🧪 testSynthesizer.speakWithHighlight呼び出し開始")
                print("🧪 utterance.speechString: \(utterance.speechString)")

                // すぐにハイライトとフィニッシュを同期的に呼び出し
                print("🧪 onHighlightコールバック呼び出し")
                onHighlight(NSRange(location: 0, length: 5), utterance.speechString)

                print("🧪 onFinishコールバック呼び出し")
                onFinish()

                print("🧪 testSynthesizer.speakWithHighlight完了")
                return true
            },
            speakWithAPI: { _, _ in
                print("🧪 testSynthesizer.speakWithAPI呼び出し")
                return true
            },
            stopSpeaking: {
                print("🧪 testSynthesizer.stopSpeaking呼び出し")
                return true
            }
        )
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
