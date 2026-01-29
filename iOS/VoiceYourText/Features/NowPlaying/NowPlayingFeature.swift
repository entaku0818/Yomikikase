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
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startPlaying(title, text, source):
                // 既存の再生を完全に停止してから新しい再生を開始
                state.isPlaying = true
                state.currentTitle = title
                state.currentText = text
                state.source = source
                state.progress = 0.0
                state.useCloudTTS = false
                state.cloudTTSAudioURL = nil
                return .run { _ in
                    // 既存の再生を完全に停止
                    _ = await speechSynthesizer.stopSpeaking()
                    // すべてのAVAudioPlayerに停止を通知
                    NotificationCenter.default.post(name: NSNotification.Name("StopAllAudioPlayers"), object: nil)
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
                return .run { _ in
                    // 既存の再生を完全に停止
                    _ = await speechSynthesizer.stopSpeaking()
                    // すべてのAVAudioPlayerに停止を通知
                    NotificationCenter.default.post(name: NSNotification.Name("StopAllAudioPlayers"), object: nil)
                }

            case .resumePlaying:
                // ミニプレイヤーから再生を再開
                guard !state.currentText.isEmpty else { return .none }
                state.isPlaying = true

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

                            let audioPlayer = try AVAudioPlayer(contentsOf: audioURL)

                            // 速度設定を適用（TextInputViewと同じロジック）
                            audioPlayer.enableRate = true
                            // AVAudioPlayerのrateは0.5〜2.0（AVSpeechUtteranceは0.0〜1.0でデフォルト0.5）
                            // speechRate 0.5 = 通常速度なので、AVAudioPlayer rate 1.0に対応
                            // speechRate 1.0 = 2倍速なので、AVAudioPlayer rate 2.0に対応
                            let speechRate = UserDefaultsManager.shared.speechRate
                            let playbackRate = max(0.5, min(2.0, speechRate * 2.0))
                            audioPlayer.rate = playbackRate

                            audioPlayer.play()

                            // Wait for playback to finish
                            while audioPlayer.isPlaying {
                                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                            }

                            await send(.speechFinished)
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

            case .stopPlaying:
                // 一時停止するがコンテンツは保持（ミニプレイヤーは表示したまま）
                state.isPlaying = false
                return .run { _ in
                    _ = await speechSynthesizer.pauseSpeaking()
                }

            case .dismiss:
                // ミニプレイヤーを完全に閉じる
                state.isPlaying = false
                state.currentTitle = ""
                state.currentText = ""
                state.progress = 0.0
                state.source = nil
                state.useCloudTTS = false
                state.cloudTTSAudioURL = nil
                return .run { _ in
                    _ = await speechSynthesizer.stopSpeaking()
                }

            case let .updateProgress(progress):
                state.progress = progress
                return .none

            case .navigateToSource:
                // 親Reducerでハンドル
                return .none

            case .speechFinished:
                state.isPlaying = false
                state.progress = 1.0
                return .none

            case .setCloudTTSMode(let useCloud):
                state.useCloudTTS = useCloud
                return .none
            }
        }
    }
}
