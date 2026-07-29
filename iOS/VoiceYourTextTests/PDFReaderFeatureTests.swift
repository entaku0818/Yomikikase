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

    override func setUp() {
        super.setUp()
        resetReviewDefaults()
    }

    override func tearDown() {
        super.tearDown()
        resetReviewDefaults()
    }

    /// PDFReaderFeature.speechFinishedはUserDefaultsManager.sharedのレビュー関連カウンタを
    /// SpeechView(Speeches)と共有するため、他テストの値が漏れ出さないようリセットする。
    private func resetReviewDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "ReviewRequestCount")
        defaults.removeObject(forKey: "SpeechCompletedCount")
        defaults.removeObject(forKey: "LastReviewRequestDate")
        defaults.removeObject(forKey: "HasAnsweredReviewPositively")
    }

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

    // MARK: - レビュー事前確認（PDF読み上げ完了）

    func test_PDF読み上げ5回目完了でレビュー事前確認が表示されること() async {
        UserDefaultsManager.shared.reviewRequestCount = 0
        UserDefaultsManager.shared.speechCompletedCount = 4  // 次で5回目

        let store = TestStore(
            initialState: PDFReaderFeature.State(pdfText: "テスト", isReading: true)
        ) {
            PDFReaderFeature()
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.speechFinished) { state in
            state.isReading = false
            state.alert = ReviewRequestPrompt.alertState(messageKey: "review.message.first")
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 1)
        XCTAssertNotNil(UserDefaultsManager.shared.lastReviewRequestDate)
    }

    func test_直近でレビュー事前確認済みの場合はPDF側5回目完了でも再表示されないこと() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 4  // 次で5回目
        UserDefaultsManager.shared.lastReviewRequestDate = Date()  // 直前に表示済み（頻度制御が効く）

        let store = TestStore(
            initialState: PDFReaderFeature.State(pdfText: "テスト", isReading: true)
        ) {
            PDFReaderFeature()
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.speechFinished) { state in
            state.isReading = false
            // 頻度制御(ReviewRequestConfig.minimumDaysBetweenPrompts)によりalertは表示されない
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 1)
    }

    // MARK: - pageTapped（複数ページPDF）

    /// テスト用の2ページPDFを生成する。各ページに一意なテキストを描画し、
    /// pageTappedがページごとに正しいテキストへ切り替わることを検証できるようにする。
    private static func makeTwoPagePDFDocument() -> PDFDocument {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            "Page One Text".draw(at: CGPoint(x: 48, y: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
            ctx.beginPage()
            "Page Two Text".draw(at: CGPoint(x: 48, y: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
        }
        guard let document = PDFDocument(data: data) else {
            fatalError("Failed to create test PDFDocument")
        }
        return document
    }

    func test_pageTapped_2ページ目をタップすると2ページ目のテキストが開始位置になること() async {
        let document = Self.makeTwoPagePDFDocument()
        XCTAssertEqual(document.pageCount, 2)

        let store = TestStore(
            initialState: PDFReaderFeature.State()
        ) {
            PDFReaderFeature()
        }

        await store.send(.pdfLoaded(document)) {
            $0.pdfDocument = document
            $0.selectedPage = 0
        }
        await store.receive(.extractTextCompleted("Page One Text")) {
            $0.pdfText = "Page One Text"
        }

        // 2ページ目(index 1)をタップ → pdfTextが2ページ目のテキストに切り替わること
        await store.send(.pageTapped(page: 1, characterIndex: 0)) {
            $0.selectedPage = 1
            $0.pdfText = "Page Two Text"
            $0.startCharacterIndex = 0
        }
    }

    func test_pageTapped_characterIndexがページ内テキスト長を超過している場合は末尾にクランプされること() async {
        let document = Self.makeTwoPagePDFDocument()

        let store = TestStore(
            initialState: PDFReaderFeature.State(pdfDocument: document)
        ) {
            PDFReaderFeature()
        }

        // "Page Two Text" は13文字。範囲外(NSNotFoundを模した巨大な値)を渡してもクラッシュせず末尾にクランプされること
        await store.send(.pageTapped(page: 1, characterIndex: NSNotFound)) {
            $0.selectedPage = 1
            $0.pdfText = "Page Two Text"
            $0.startCharacterIndex = "Page Two Text".count
        }
    }

    func test_pageTapped_存在しないページ番号の場合は状態を変更しないこと() async {
        let document = Self.makeTwoPagePDFDocument()

        let store = TestStore(
            initialState: PDFReaderFeature.State(pdfText: "既存テキスト", pdfDocument: document)
        ) {
            PDFReaderFeature()
        }

        // ページ数(2)を超えるページ番号 → document.page(at:)がnilを返すため何も変更しない
        await store.send(.pageTapped(page: 99, characterIndex: 0))
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
