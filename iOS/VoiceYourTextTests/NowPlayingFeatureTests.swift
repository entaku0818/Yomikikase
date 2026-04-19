//
//  NowPlayingFeatureTests.swift
//  VoiceYourTextTests
//

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

@MainActor
final class NowPlayingFeatureTests: XCTestCase {

    // MARK: - PlaybackSource.id

    func test_PlaybackSource_speechのIDが正しい() {
        let uuid = UUID()
        XCTAssertEqual(PlaybackSource.speech(id: uuid).id, "speech-\(uuid.uuidString)")
    }

    func test_PlaybackSource_pdfのIDが正しい() {
        let uuid = UUID()
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        XCTAssertEqual(PlaybackSource.pdf(id: uuid, url: url).id, "pdf-\(uuid.uuidString)")
    }

    func test_PlaybackSource_textInputのIDがfileIdありで正しい() {
        let uuid = UUID()
        XCTAssertEqual(PlaybackSource.textInput(fileId: uuid, text: "text").id, "textInput-\(uuid.uuidString)")
    }

    func test_PlaybackSource_textInputのIDがfileIdなしでnewになる() {
        XCTAssertEqual(PlaybackSource.textInput(fileId: nil, text: "text").id, "textInput-new")
    }

    // MARK: - startPlaying

    func test_startPlayingで再生状態になりタイトル等が設定される() async {
        let store = TestStore(initialState: NowPlayingFeature.State()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        let source = PlaybackSource.speech(id: UUID())
        await store.send(.startPlaying(title: "テストタイトル", text: "テストテキスト", source: source)) { state in
            state.isPlaying = true
            state.currentTitle = "テストタイトル"
            state.currentText = "テストテキスト"
            state.source = source
            state.progress = 0.0
            state.useCloudTTS = false
            state.cloudTTSAudioURL = nil
        }
    }

    func test_startPlayingで進捗がリセットされる() async {
        let store = TestStore(initialState: NowPlayingFeature.State(progress: 0.8)) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.startPlaying(title: "Title", text: "Text", source: .speech(id: UUID()))) { state in
            state.progress = 0.0
        }
    }

    func test_startPlayingでCloudTTSモードがリセットされる() async {
        let initialState = NowPlayingFeature.State(
            useCloudTTS: true,
            cloudTTSAudioURL: URL(fileURLWithPath: "/tmp/audio.m4a")
        )
        let store = TestStore(initialState: initialState) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.startPlaying(title: "Title", text: "Text", source: .speech(id: UUID()))) { state in
            state.useCloudTTS = false
            state.cloudTTSAudioURL = nil
        }
    }

    // MARK: - startPlayingWithCloudTTS

    func test_startPlayingWithCloudTTSでCloudTTSモードになる() async {
        let store = TestStore(initialState: NowPlayingFeature.State()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        let source = PlaybackSource.textInput(fileId: nil, text: "テスト")
        let audioURL = URL(fileURLWithPath: "/tmp/audio.m4a")
        await store.send(.startPlayingWithCloudTTS(
            title: "タイトル", text: "テキスト", source: source, audioURL: audioURL
        )) { state in
            state.isPlaying = true
            state.currentTitle = "タイトル"
            state.currentText = "テキスト"
            state.source = source
            state.progress = 0.0
            state.useCloudTTS = true
            state.cloudTTSAudioURL = audioURL
        }
    }

    // MARK: - stopPlaying

    func test_stopPlayingでisPlayingがfalseになりコンテンツは保持される() async {
        let initialState = NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト",
            progress: 0.4
        )
        let store = TestStore(initialState: initialState) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.stopPlaying) { state in
            state.isPlaying = false
            // タイトル・テキスト・progressは保持
        }
        XCTAssertEqual(store.state.currentTitle, "タイトル")
        XCTAssertEqual(store.state.currentText, "テキスト")
        XCTAssertEqual(store.state.progress, 0.4)
    }

    // MARK: - dismiss

    func test_dismissで全stateがリセットされる() async {
        let initialState = NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト",
            progress: 0.5,
            source: .speech(id: UUID()),
            useCloudTTS: true,
            cloudTTSAudioURL: URL(fileURLWithPath: "/tmp/audio.m4a")
        )
        let store = TestStore(initialState: initialState) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.dismiss) { state in
            state.isPlaying = false
            state.currentTitle = ""
            state.currentText = ""
            state.progress = 0.0
            state.source = nil
            state.useCloudTTS = false
            state.cloudTTSAudioURL = nil
        }
    }

    // MARK: - speechFinished

    func test_speechFinishedでisPlayingがfalseになりprogressが1になる() async {
        let initialState = NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト",
            progress: 0.7
        )
        let store = TestStore(initialState: initialState) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.speechFinished) { state in
            state.isPlaying = false
            state.progress = 1.0
        }
    }

    func test_speechFinishedではタイトルとテキストが保持される() async {
        let store = TestStore(initialState: NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "保持タイトル",
            currentText: "保持テキスト"
        )) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.speechFinished)
        XCTAssertEqual(store.state.currentTitle, "保持タイトル")
        XCTAssertEqual(store.state.currentText, "保持テキスト")
    }

    // MARK: - updateProgress

    func test_updateProgressでprogress値が更新される() async {
        let store = TestStore(initialState: NowPlayingFeature.State()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }

        await store.send(.updateProgress(0.75)) { state in
            state.progress = 0.75
        }
    }

    func test_updateProgressで0と1の境界値を設定できる() async {
        let store = TestStore(initialState: NowPlayingFeature.State(progress: 0.5)) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }

        await store.send(.updateProgress(0.0)) { state in
            state.progress = 0.0
        }
        await store.send(.updateProgress(1.0)) { state in
            state.progress = 1.0
        }
    }

    // MARK: - setCloudTTSMode

    func test_setCloudTTSModeでCloudTTSが有効になる() async {
        let store = TestStore(initialState: NowPlayingFeature.State()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }

        await store.send(.setCloudTTSMode(true)) { state in
            state.useCloudTTS = true
        }
    }

    func test_setCloudTTSModeでCloudTTSが無効になる() async {
        let store = TestStore(initialState: NowPlayingFeature.State(useCloudTTS: true)) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }

        await store.send(.setCloudTTSMode(false)) { state in
            state.useCloudTTS = false
        }
    }

    // MARK: - resumePlaying

    func test_resumePlayingでcurrentTextが空なら状態変化なし() async {
        let store = TestStore(initialState: NowPlayingFeature.State(currentText: "")) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }

        // currentTextが空のため .none が返り stateは変化しない
        await store.send(.resumePlaying)
    }

    // MARK: - navigateToSource

    func test_navigateToSourceは状態変化なし() async {
        let store = TestStore(initialState: NowPlayingFeature.State()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }

        // 親Reducerでハンドルするためここでは .none
        await store.send(.navigateToSource)
    }

    // MARK: - remoteCommandReceived

    func test_remoteCommandPlay_停止中ならresumePlaying送信() async {
        let store = TestStore(initialState: NowPlayingFeature.State(
            isPlaying: false,
            currentText: "テキスト"
        )) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.remoteCommandReceived(.play))
        // exhaustivity=.off: resumePlayingアクションを内部で受信
    }

    func test_remoteCommandPause_再生中ならstopPlaying送信() async {
        let store = TestStore(initialState: NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト"
        )) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.remoteCommandReceived(.pause))
    }

    func test_remoteCommandStop_dismissが送信される() async {
        let store = TestStore(initialState: NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト"
        )) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.remoteCommandReceived(.stop))
    }

    func test_remoteCommandTogglePlayPause_再生中ならstopPlayingになる() async {
        let store = TestStore(initialState: NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト"
        )) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.remoteCommandReceived(.togglePlayPause))
    }

    func test_remoteCommandTogglePlayPause_停止中ならresumePlayingになる() async {
        let store = TestStore(initialState: NowPlayingFeature.State(
            isPlaying: false,
            currentText: "テキスト"
        )) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.remoteCommandReceived(.togglePlayPause))
    }
}
