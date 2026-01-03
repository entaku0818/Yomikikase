//
//  NowPlayingFeature.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

import ComposableArchitecture
import Foundation

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
        case stopPlaying
        case dismiss  // ミニプレイヤーを完全に閉じる
        case updateProgress(Double)
        case navigateToSource
        case pauseToggle
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

            case .pauseToggle:
                // TODO: 一時停止/再開処理（AVSpeechSynthesizerは一時停止に対応していない場合あり）
                return .none
            }
        }
    }
}
