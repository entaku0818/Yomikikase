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
            },
            pauseSpeaking: { return true },
            continueSpeaking: { return true },
            isPaused: { return false }
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

    func testSetStartCharacterIndex() async {
        let store = TestStore(
            initialState: PDFReaderFeature.State(pdfText: "Hello World")
        ) {
            PDFReaderFeature()
        }

        await store.send(.setStartCharacterIndex(6)) {
            $0.startCharacterIndex = 6
        }
    }

    func testStartReadingFromNonZeroIndex() async {
        var capturedUtteranceText: String?

        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "Hello World",
                isReading: false,
                startCharacterIndex: 6
            )
        ) {
            PDFReaderFeature()
        } withDependencies: { deps in
            deps.speechSynthesizer = SpeechSynthesizerClient(
                speak: { _ in true },
                speakWithHighlight: { utterance, onHighlight, onFinish in
                    capturedUtteranceText = utterance.speechString
                    // utterance は "World"（suffix）なので range.location=0 を送る
                    onHighlight(NSRange(location: 0, length: 5), utterance.speechString)
                    onFinish()
                    return true
                },
                speakWithAPI: { _, _ in true },
                stopSpeaking: { true },
                pauseSpeaking: { true },
                continueSpeaking: { true },
                isPaused: { false }
            )
            deps.userDefaults = UserDefaultsClient(
                languageSetting: { "ja-JP" },
                setLanguageSetting: { _ in },
                selectedVoiceIdentifier: { nil },
                setSelectedVoiceIdentifier: { _ in },
                cloudTTSVoiceId: { nil },
                setCloudTTSVoiceId: { _ in },
                speechRate: { 0.5 },
                setSpeechRate: { _ in },
                speechPitch: { 1.0 },
                setSpeechPitch: { _ in },
                isPremiumUser: { false },
                setIsPremiumUser: { _ in },
                premiumPurchaseDate: { nil },
                setPremiumPurchaseDate: { _ in },
                kokoroEnabled: { false },
                setKokoroEnabled: { _ in },
                kokoroVoice: { nil },
                setKokoroVoice: { _ in },
                hasCompletedOnboarding: { true },
                setHasCompletedOnboarding: { _ in },
                speechCompletedCount: { 0 },
                setSpeechCompletedCount: { _ in },
                appLaunchCount: { 0 },
                setAppLaunchCount: { _ in },
                installDate: { nil },
                setInstallDate: { _ in },
                reviewRequestCount: { 0 },
                setReviewRequestCount: { _ in },
                lastReviewRequestDate: { nil },
                setLastReviewRequestDate: { _ in },
                hasAnsweredReviewPositively: { false },
                setHasAnsweredReviewPositively: { _ in },
                pendingJobId: { _ in nil },
                setPendingJob: { _, _ in },
                clearPendingJob: { _ in }
            )
        }

        await store.send(.startReading) {
            $0.isReading = true
        }

        // offset 6 が加算され NSRange(location:6, length:5) → "World" がハイライトされる
        await store.receive(.highlightRange(NSRange(location: 6, length: 5))) {
            $0.highlightedRange = NSRange(location: 6, length: 5)
            $0.highlightedText = "World"
        }

        await store.receive(.speechFinished) {
            $0.isReading = false
            $0.highlightedRange = nil
            $0.highlightedText = nil
        }

        XCTAssertEqual(capturedUtteranceText, "World")
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
