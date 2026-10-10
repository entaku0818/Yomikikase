//
//  PlaybackResumeTests.swift
//  VoiceYourTextTests
//

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

/// 停止しても続きから聞ける（停止位置の記憶）のテスト
@MainActor
final class PlaybackResumeTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "PlaybackResumeTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - PlaybackResumeStore

    func test_止めた位置を保存すると同じ文章で取り出せる() {
        let store = PlaybackResumeStore(defaults: defaults)
        let id = UUID()
        store.save(5, fileId: id, text: "こんにちは。今日は晴れです。")

        XCTAssertEqual(store.position(fileId: id, text: "こんにちは。今日は晴れです。"), 5)
    }

    func test_文章が変わっていたら止めた位置を使わない() {
        let store = PlaybackResumeStore(defaults: defaults)
        let id = UUID()
        store.save(5, fileId: id, text: "こんにちは。今日は晴れです。")

        XCTAssertNil(store.position(fileId: id, text: "こんにちは。明日は雨です。"))
    }

    func test_先頭と末尾は続きとして覚えない() {
        let store = PlaybackResumeStore(defaults: defaults)
        let id = UUID()
        let text = "abc"
        store.save(1, fileId: id, text: text)
        store.save(0, fileId: id, text: text)
        XCTAssertNil(store.position(fileId: id, text: text))

        store.save(3, fileId: id, text: text)
        XCTAssertNil(store.position(fileId: id, text: text))
    }

    func test_clearで止めた位置が消える() {
        let store = PlaybackResumeStore(defaults: defaults)
        let id = UUID()
        store.save(2, fileId: id, text: "abcdef")
        store.clear(fileId: id)

        XCTAssertNil(store.position(fileId: id, text: "abcdef"))
    }

    func test_ファイルごとに別々に覚える() {
        let store = PlaybackResumeStore(defaults: defaults)
        let first = UUID()
        let second = UUID()
        store.save(2, fileId: first, text: "abcdef")
        store.save(4, fileId: second, text: "abcdef")

        XCTAssertEqual(store.position(fileId: first, text: "abcdef"), 2)
        XCTAssertEqual(store.position(fileId: second, text: "abcdef"), 4)
    }

    func test_fingerprintは同じ文章なら毎回同じ値() {
        XCTAssertEqual(PlaybackResumeStore.fingerprint("読み上げ"), PlaybackResumeStore.fingerprint("読み上げ"))
        XCTAssertNotEqual(PlaybackResumeStore.fingerprint("読み上げ"), PlaybackResumeStore.fingerprint("読み上げる"))
    }

    func test_remainderは指定位置から後ろの文章を返す() {
        let result = PlaybackResumeStore.remainder(of: "Hello World", fromUTF16Offset: 6)
        XCTAssertEqual(result.text, "World")
        XCTAssertEqual(result.base, 6)
    }

    func test_remainderは絵文字の途中を指していたら文字の先頭まで戻す() {
        // 😀 は UTF-16 で2つ分。2 は 😀 の後半を指している
        let result = PlaybackResumeStore.remainder(of: "a😀b", fromUTF16Offset: 2)
        XCTAssertEqual(result.text, "😀b")
        XCTAssertEqual(result.base, 1)
    }

    func test_remainderは範囲外を丸める() {
        XCTAssertEqual(PlaybackResumeStore.remainder(of: "abc", fromUTF16Offset: -3).text, "abc")
        XCTAssertEqual(PlaybackResumeStore.remainder(of: "abc", fromUTF16Offset: 10).text, "")
    }

    // MARK: - PDFReaderFeature

    func test_PDFを停止すると読んでいた位置から次の再生を始める() async {
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "Hello World",
                isReading: true,
                highlightedRange: NSRange(location: 6, length: 5),
                highlightedText: "World"
            )
        ) {
            PDFReaderFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
        }

        // ハイライトは止めた位置の目印として残す
        await store.send(.stopReading) {
            $0.isReading = false
            $0.startCharacterIndex = 6
            $0.isResumingFromStop = true
        }
    }

    func test_PDFの停止位置は絵文字があっても文字単位に直す() async {
        // "😀😀 World" の "World" は UTF-16 で 5、Character で 3
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "😀😀 World",
                isReading: true,
                highlightedRange: NSRange(location: 5, length: 5),
                highlightedText: "World"
            )
        ) {
            PDFReaderFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
        }

        await store.send(.stopReading) {
            $0.isReading = false
            $0.startCharacterIndex = 3
            $0.isResumingFromStop = true
        }
    }

    func test_PDFを読んでいないときの停止では位置を変えない() async {
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "Hello World",
                isReading: false,
                highlightedRange: NSRange(location: 6, length: 5),
                startCharacterIndex: 0
            )
        ) {
            PDFReaderFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
        }

        await store.send(.stopReading)
    }

    func test_PDFでページをタップしたら続きからの状態を解除する() async {
        let store = TestStore(
            initialState: PDFReaderFeature.State(
                pdfText: "Hello World",
                startCharacterIndex: 6,
                isResumingFromStop: true
            )
        ) {
            PDFReaderFeature()
        }

        await store.send(.setStartCharacterIndex(2)) {
            $0.startCharacterIndex = 2
            $0.isResumingFromStop = false
        }
    }

    func test_characterOffsetはUTF16位置をCharacter位置に直す() {
        XCTAssertEqual(PDFReaderFeature.characterOffset(ofUTF16Location: 6, in: "Hello World"), 6)
        XCTAssertEqual(PDFReaderFeature.characterOffset(ofUTF16Location: 5, in: "😀😀 World"), 3)
        // 絵文字の後半を指していたら、その絵文字の位置
        XCTAssertEqual(PDFReaderFeature.characterOffset(ofUTF16Location: 1, in: "😀a"), 0)
        XCTAssertNil(PDFReaderFeature.characterOffset(ofUTF16Location: 99, in: "abc"))
    }
}
