//
//  SleepTimerTests.swift
//  VoiceYourTextTests
//
//  スリープタイマー（#121）のテスト。
//

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

// MARK: - モデル

final class SleepTimerOptionTests: XCTestCase {

    func test_プリセットは5から60分と章末の7種類() {
        XCTAssertEqual(
            SleepTimerOption.presets,
            [.minutes(5), .minutes(10), .minutes(15), .minutes(30), .minutes(45), .minutes(60), .endOfChapter]
        )
    }

    func test_分指定のtotalSecondsは分の60倍() {
        XCTAssertEqual(SleepTimerOption.minutes(5).totalSeconds, 300)
        XCTAssertEqual(SleepTimerOption.minutes(60).totalSeconds, 3600)
    }

    func test_章末指定は時間で切らないためtotalSecondsがnil() {
        XCTAssertNil(SleepTimerOption.endOfChapter.totalSeconds)
    }

    func test_idが選択肢ごとに一意() {
        let ids = SleepTimerOption.presets.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_残り秒数は分秒表記になる() {
        XCTAssertEqual(SleepTimerState.formattedRemaining(300), "5:00")
        XCTAssertEqual(SleepTimerState.formattedRemaining(59), "0:59")
        XCTAssertEqual(SleepTimerState.formattedRemaining(61), "1:01")
        XCTAssertEqual(SleepTimerState.formattedRemaining(0), "0:00")
    }

    func test_1時間以上は時分秒表記になる() {
        XCTAssertEqual(SleepTimerState.formattedRemaining(3600), "1:00:00")
        XCTAssertEqual(SleepTimerState.formattedRemaining(3661), "1:01:01")
    }

    func test_残り秒数が負でも0として扱う() {
        XCTAssertEqual(SleepTimerState.formattedRemaining(-5), "0:00")
    }

    func test_分指定のstateは残り秒数が初期化される() {
        XCTAssertEqual(SleepTimerState(option: .minutes(15)).remainingSeconds, 900)
    }

    func test_章末指定のstateは残り秒数を持たない() {
        let state = SleepTimerState(option: .endOfChapter)
        XCTAssertNil(state.remainingSeconds)
        // 残り時間の代わりに章末までであることを表示する
        XCTAssertFalse(state.displayText.isEmpty)
    }

    func test_分指定のdisplayTextは残り時間() {
        XCTAssertEqual(SleepTimerState(option: .minutes(10)).displayText, "10:00")
    }
}

// MARK: - Reducer

@MainActor
final class SleepTimerFeatureTests: XCTestCase {

    private func playingState(
        sleepTimer: SleepTimerState? = nil
    ) -> NowPlayingFeature.State {
        NowPlayingFeature.State(
            isPlaying: true,
            currentTitle: "タイトル",
            currentText: "テキスト",
            sleepTimer: sleepTimer
        )
    }

    func test_タイマーを設定すると残り時間がセットされ1秒ごとに減る() async {
        let clock = TestClock()
        let store = TestStore(initialState: playingState()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = clock
        }

        await store.send(.setSleepTimer(.minutes(5))) { state in
            state.sleepTimer = SleepTimerState(option: .minutes(5))
        }
        XCTAssertEqual(store.state.sleepTimer?.remainingSeconds, 300)

        await clock.advance(by: .seconds(1))
        await store.receive(.sleepTimerTicked) { state in
            state.sleepTimer?.remainingSeconds = 299
        }

        await clock.advance(by: .seconds(2))
        await store.receive(.sleepTimerTicked) { state in
            state.sleepTimer?.remainingSeconds = 298
        }
        await store.receive(.sleepTimerTicked) { state in
            state.sleepTimer?.remainingSeconds = 297
        }

        // 後片付け（作動中のカウントダウンEffectを止める）
        await store.send(.setSleepTimer(nil)) { state in
            state.sleepTimer = nil
        }
    }

    func test_タイマーを解除するとカウントダウンが止まる() async {
        let clock = TestClock()
        let store = TestStore(initialState: playingState()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = clock
        }

        await store.send(.setSleepTimer(.minutes(10))) { state in
            state.sleepTimer = SleepTimerState(option: .minutes(10))
        }
        await store.send(.setSleepTimer(nil)) { state in
            state.sleepTimer = nil
        }

        // 解除後に時間を進めても tick が来ない（来れば未処理アクションでテスト失敗）
        await clock.advance(by: .seconds(5))
    }

    func test_タイマーを再設定すると残り時間がリセットされる() async {
        let clock = TestClock()
        let store = TestStore(initialState: playingState()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = clock
        }

        await store.send(.setSleepTimer(.minutes(5))) { state in
            state.sleepTimer = SleepTimerState(option: .minutes(5))
        }
        await clock.advance(by: .seconds(1))
        await store.receive(.sleepTimerTicked) { state in
            state.sleepTimer?.remainingSeconds = 299
        }

        await store.send(.setSleepTimer(.minutes(30))) { state in
            state.sleepTimer = SleepTimerState(option: .minutes(30))
        }
        XCTAssertEqual(store.state.sleepTimer?.remainingSeconds, 1800)

        // 前のカウントダウンが二重に走っていないこと（1秒で1回だけ tick）
        await clock.advance(by: .seconds(1))
        await store.receive(.sleepTimerTicked) { state in
            state.sleepTimer?.remainingSeconds = 1799
        }

        await store.send(.setSleepTimer(nil)) { state in
            state.sleepTimer = nil
        }
    }

    func test_残り0秒でタイマーが作動しフェードアウトして停止する() async {
        let clock = TestClock()
        let fadeSeconds = LockIsolated<Double?>(nil)

        let store = TestStore(
            initialState: playingState(
                sleepTimer: SleepTimerState(option: .minutes(5), remainingSeconds: 1)
            )
        ) {
            NowPlayingFeature()
        } withDependencies: {
            $0.nowPlayingClient = .testValue
            $0.continuousClock = clock
            $0.speechSynthesizer = SpeechSynthesizerClient(
                speak: { _ in true },
                speakWithHighlight: { _, _, _ in true },
                speakWithAPI: { _, _ in true },
                stopSpeaking: { true },
                pauseSpeaking: { true },
                continueSpeaking: { true },
                isPaused: { false },
                fadeOutAndStop: { seconds in
                    fadeSeconds.setValue(seconds)
                    return true
                }
            )
        }

        await store.send(.sleepTimerTicked) { state in
            state.sleepTimer?.remainingSeconds = 0
        }

        await store.receive(.sleepTimerFired) { state in
            state.sleepTimer = nil
            state.isPlaying = false
        }
        await store.finish()

        XCTAssertEqual(
            fadeSeconds.value, NowPlayingFeature.sleepTimerFadeOutSeconds,
            "タイマー作動時は即停止ではなくフェードアウトしてから止める"
        )
        // 再開できるようコンテンツは残す
        XCTAssertEqual(store.state.currentTitle, "タイトル")
        XCTAssertEqual(store.state.currentText, "テキスト")
    }

    func test_タイマー作動までカウントダウンが継続する() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: playingState(
                sleepTimer: SleepTimerState(option: .minutes(5), remainingSeconds: 3)
            )
        ) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = clock
        }
        // カウントダウンEffectを起動しないので、tick は手動で送る
        await store.send(.sleepTimerTicked) { $0.sleepTimer?.remainingSeconds = 2 }
        await store.send(.sleepTimerTicked) { $0.sleepTimer?.remainingSeconds = 1 }
        await store.send(.sleepTimerTicked) { $0.sleepTimer?.remainingSeconds = 0 }
        await store.receive(.sleepTimerFired) { state in
            state.sleepTimer = nil
            state.isPlaying = false
        }
        await store.finish()
    }

    func test_タイマー未設定のtickは何もしない() async {
        let store = TestStore(initialState: playingState()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = TestClock()
        }

        // state 変化なし・Effectなしで完了する
        await store.send(.sleepTimerTicked)
    }

    func test_章末指定はカウントダウンしない() async {
        let clock = TestClock()
        let store = TestStore(initialState: playingState()) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = clock
        }

        await store.send(.setSleepTimer(.endOfChapter)) { state in
            state.sleepTimer = SleepTimerState(option: .endOfChapter)
        }
        XCTAssertNil(store.state.sleepTimer?.remainingSeconds)

        // 時間を進めても tick は来ない（来れば未処理アクションでテスト失敗）
        await clock.advance(by: .seconds(120))
    }

    func test_章末指定は読み上げ完了で解除される() async {
        let store = TestStore(
            initialState: playingState(sleepTimer: SleepTimerState(option: .endOfChapter))
        ) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.speechFinished) { state in
            state.isPlaying = false
            state.sleepTimer = nil
        }
    }

    func test_ミニプレイヤーを閉じるとタイマーも解除される() async {
        let store = TestStore(
            initialState: playingState(
                sleepTimer: SleepTimerState(option: .minutes(30), remainingSeconds: 1500)
            )
        ) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.dismiss) { state in
            state.sleepTimer = nil
        }
    }

    func test_一時停止ではタイマーを維持する() async {
        // 一時停止してすぐ再開する操作でタイマーが消えると使い勝手が悪いため保持する
        let timer = SleepTimerState(option: .minutes(30), remainingSeconds: 1500)
        let store = TestStore(initialState: playingState(sleepTimer: timer)) {
            NowPlayingFeature()
        } withDependencies: {
            $0.speechSynthesizer = .testValue
            $0.nowPlayingClient = .testValue
            $0.continuousClock = TestClock()
        }
        store.exhaustivity = .off

        await store.send(.stopPlaying) { state in
            state.isPlaying = false
        }
        XCTAssertEqual(store.state.sleepTimer, timer)
    }
}
