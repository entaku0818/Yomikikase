//
//  NowPlayingFeature.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

import ComposableArchitecture
import Foundation
import AVFoundation

enum PlaybackSource: Equatable, Identifiable {
    case speech(id: UUID)
    case pdf(id: UUID, url: URL)
    case textInput(fileId: UUID?, text: String)

    var id: String {
        switch self {
        case .speech(let id):
            return "speech-\(id.uuidString)"
        case .pdf(let id, _):
            return "pdf-\(id.uuidString)"
        case .textInput(let fileId, _):
            return "textInput-\(fileId?.uuidString ?? "new")"
        }
    }
}

@Reducer
struct NowPlayingFeature {
    @ObservableState
    struct State: Equatable {
        var isPlaying: Bool = false
        var currentTitle: String = ""
        var currentText: String = ""
        var progress: Double = 0.0
        var source: PlaybackSource? = nil
        var useCloudTTS: Bool = false
        var cloudTTSAudioURL: URL? = nil
        var isGeneratingAudio: Bool = false
    }

    enum Action: Equatable {
        case startPlaying(title: String, text: String, source: PlaybackSource)
        case startPlayingWithCloudTTS(title: String, text: String, source: PlaybackSource, audioURL: URL)
        case resumePlaying  // ミニプレイヤーから再生を再開
        case stopPlaying
        case dismiss  // ミニプレイヤーを完全に閉じる
        case updateProgress(Double)
        case navigateToSource
        case speechFinished
        case setCloudTTSMode(Bool)
        case observeRemoteCommands
        case remoteCommandReceived(RemoteCommandEvent)
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer
    @Dependency(\.nowPlayingClient) var nowPlayingClient

    private enum CancelID { case remoteCommands, playback }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startPlaying(title, text, source):
                state.isPlaying = true
                state.currentTitle = title
                state.currentText = text
                state.source = source
                state.progress = 0.0
                state.useCloudTTS = false
                state.cloudTTSAudioURL = nil
                nowPlayingClient.updateNowPlayingInfo(title, true)
                return .run { send in
                    // SpeechSynthesizer 内部で stop() を呼ぶため、ここでの stopSpeaking() は不要かつレースコンディションの原因になる
                    await send(.observeRemoteCommands)
                }

            case let .startPlayingWithCloudTTS(title, text, source, audioURL):
                // 既存の再生を完全に停止してから新しい再生を開始
                state.isPlaying = true
                state.currentTitle = title
                state.currentText = text
                state.source = source
                state.progress = 0.0
                state.useCloudTTS = true
                state.cloudTTSAudioURL = audioURL
                nowPlayingClient.updateNowPlayingInfo(title, true)
                return .run { send in
                    // 既存の再生を完全に停止
                    _ = await speechSynthesizer.stopSpeaking()
                    // すべてのAVAudioPlayerに停止を通知
                    NotificationCenter.default.post(name: NSNotification.Name("StopAllAudioPlayers"), object: nil)
                    await send(.observeRemoteCommands)
                }

            case .resumePlaying:
                // ミニプレイヤーから再生を再開
                guard !state.currentText.isEmpty else { return .none }
                state.isPlaying = true
                nowPlayingClient.updateNowPlayingInfo(state.currentTitle, true)

                let text = state.currentText
                let useCloudTTS = state.useCloudTTS
                let cloudTTSAudioURL = state.cloudTTSAudioURL

                return .run { send in
                    if useCloudTTS, let audioURL = cloudTTSAudioURL {
                        // Cloud TTS mode - play from local audio file
                        do {
                            let audioSession = AVAudioSession.sharedInstance()
                            try audioSession.setCategory(.playback, mode: .spokenAudio)
                            try audioSession.setActive(true)

                            let player = try AVAudioPlayer(contentsOf: audioURL)
                            player.enableRate = true
                            let speechRate = UserDefaultsManager.shared.speechRate
                            player.rate = max(0.5, min(2.0, speechRate * 2.0))
                            player.play()

                            try await withTaskCancellationHandler {
                                while player.isPlaying {
                                    try await Task.sleep(nanoseconds: 100_000_000)
                                }
                            } onCancel: {
                                player.stop()
                            }

                            if !Task.isCancelled {
                                await send(.speechFinished)
                            }
                        } catch is CancellationError {
                            // stopPlaying によりキャンセル済み、何もしない
                        } catch {
                            errorLog("Cloud TTS playback failed: \(error)")
                            await send(.speechFinished)
                        }
                    } else {
                        // Local TTS mode
                        // 一時停止中なら再開、そうでなければ新規再生
                        let isPaused = await speechSynthesizer.isPaused()
                        if isPaused {
                            _ = await speechSynthesizer.continueSpeaking()
                        } else {
                            // 音声セッションの設定
                            let audioSession = AVAudioSession.sharedInstance()
                            do {
                                try audioSession.setCategory(.playback, mode: .spokenAudio)
                                try audioSession.setActive(true)
                            } catch {
                                errorLog("Failed to set audio session category: \(error)")
                            }

                            // ユーザー設定から音声設定を取得
                            let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
                            let rate = UserDefaultsManager.shared.speechRate
                            let pitch = UserDefaultsManager.shared.speechPitch
                            let volume: Float = 0.75

                            let utterance = AVSpeechUtterance(string: text)
                            utterance.voice = AVSpeechSynthesisVoice(language: language)
                            utterance.rate = rate
                            utterance.pitchMultiplier = pitch
                            utterance.volume = volume

                            do {
                                try await speechSynthesizer.speakWithHighlight(
                                    utterance,
                                    { _, _ in
                                        // ハイライト更新（ミニプレイヤーでは不要）
                                    },
                                    {
                                        // 読み上げ完了
                                        Task { @MainActor in
                                            await send(.speechFinished)
                                        }
                                    }
                                )
                            } catch {
                                errorLog("Speech synthesis failed: \(error)")
                                await send(.speechFinished)
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.playback, cancelInFlight: true)

            case .stopPlaying:
                // 一時停止するがコンテンツは保持（ミニプレイヤーは表示したまま）
                // pauseSpeaking() は呼ばない: 完了後の stopPlaying が次の再生を即座に pause するレースコンディションの原因になる
                // ミニプレイヤーからの停止に対応するため playback をキャンセルし synthesizer も止める
                state.isPlaying = false
                nowPlayingClient.updateNowPlayingInfo(state.currentTitle, false)
                return .merge(
                    .cancel(id: CancelID.playback),
                    .run { _ in _ = await speechSynthesizer.stopSpeaking() }
                )

            case .dismiss:
                // ミニプレイヤーを完全に閉じる
                state.isPlaying = false
                state.currentTitle = ""
                state.currentText = ""
                state.progress = 0.0
                state.source = nil
                state.useCloudTTS = false
                state.cloudTTSAudioURL = nil
                nowPlayingClient.clearNowPlayingInfo()
                return .merge(
                    .cancel(id: CancelID.remoteCommands),
                    .cancel(id: CancelID.playback),
                    .run { _ in
                        _ = await speechSynthesizer.stopSpeaking()
                        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    }
                )

            case let .updateProgress(progress):
                state.progress = progress
                return .none

            case .navigateToSource:
                // 親Reducerでハンドル
                return .none

            case .speechFinished:
                state.isPlaying = false
                state.progress = 1.0
                nowPlayingClient.clearNowPlayingInfo()
                return .merge(
                    .cancel(id: CancelID.remoteCommands),
                    .cancel(id: CancelID.playback),
                    .run { _ in
                        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    }
                )

            case .setCloudTTSMode(let useCloud):
                state.useCloudTTS = useCloud
                return .none

            case .observeRemoteCommands:
                return .merge(
                    .run { send in
                        for await event in nowPlayingClient.remoteCommandEvents() {
                            await send(.remoteCommandReceived(event))
                        }
                    },
                    .run { send in
                        for await notification in NotificationCenter.default.notifications(
                            named: AVAudioSession.interruptionNotification
                        ) {
                            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                                  typeValue == AVAudioSession.InterruptionType.began.rawValue else { continue }
                            await send(.stopPlaying)
                        }
                    }
                )
                .cancellable(id: CancelID.remoteCommands, cancelInFlight: true)

            case .remoteCommandReceived(let event):
                switch event {
                case .play, .togglePlayPause where !state.isPlaying:
                    return .send(.resumePlaying)
                case .pause, .togglePlayPause where state.isPlaying:
                    return .send(.stopPlaying)
                case .stop:
                    return .send(.dismiss)
                default:
                    return .none
                }
            }
        }
    }
}
