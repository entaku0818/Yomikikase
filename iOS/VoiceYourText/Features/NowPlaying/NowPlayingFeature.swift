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
    }

    enum Action: Equatable {
        case startPlaying(title: String, text: String, source: PlaybackSource)
        case resumePlaying  // ミニプレイヤーから再生を再開
        case stopPlaying
        case dismiss  // ミニプレイヤーを完全に閉じる
        case updateProgress(Double)
        case navigateToSource
        case speechFinished
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startPlaying(title, text, source):
                state.isPlaying = true
                state.currentTitle = title
                state.currentText = text
                state.source = source
                state.progress = 0.0
                return .none

            case .resumePlaying:
                // ミニプレイヤーから再生を開始
                guard !state.currentText.isEmpty else { return .none }
                state.isPlaying = true
                state.progress = 0.0

                let text = state.currentText

                return .run { send in
                    // 音声セッションの設定
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                        try audioSession.setActive(true)
                    } catch {
                        print("Failed to set audio session category: \(error)")
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
                        print("Speech synthesis failed: \(error)")
                        await send(.speechFinished)
                    }
                }

            case .stopPlaying:
                // 停止するがコンテンツは保持（ミニプレイヤーは表示したまま）
                state.isPlaying = false
                return .run { _ in
                    _ = await speechSynthesizer.stopSpeaking()
                }

            case .dismiss:
                // ミニプレイヤーを完全に閉じる
                state.isPlaying = false
                state.currentTitle = ""
                state.currentText = ""
                state.progress = 0.0
                state.source = nil
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
            }
        }
    }
}
