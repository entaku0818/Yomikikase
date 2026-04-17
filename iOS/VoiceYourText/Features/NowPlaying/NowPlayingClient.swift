//
//  NowPlayingClient.swift
//  VoiceYourText
//

import Foundation
import MediaPlayer
import Dependencies
import ComposableArchitecture

enum RemoteCommandEvent: Equatable, Sendable {
    case play
    case pause
    case togglePlayPause
    case stop
}

@DependencyClient
struct NowPlayingClient: Sendable {
    var updateNowPlayingInfo: @Sendable (_ title: String, _ isPlaying: Bool) -> Void = { _, _ in }
    var clearNowPlayingInfo: @Sendable () -> Void = {}
    var remoteCommandEvents: @Sendable () -> AsyncStream<RemoteCommandEvent> = { .finished }
}

extension NowPlayingClient: DependencyKey {
    static var liveValue: Self {
        let (stream, continuation) = AsyncStream<RemoteCommandEvent>.makeStream()

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true
        // 前後スキップは不要なので無効化
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false

        center.playCommand.addTarget { _ in
            continuation.yield(.play)
            return .success
        }
        center.pauseCommand.addTarget { _ in
            continuation.yield(.pause)
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            continuation.yield(.togglePlayPause)
            return .success
        }
        center.stopCommand.addTarget { _ in
            continuation.yield(.stop)
            return .success
        }

        return Self(
            updateNowPlayingInfo: { title, isPlaying in
                var info: [String: Any] = [:]
                info[MPMediaItemPropertyTitle] = title
                info[MPMediaItemPropertyArtist] = "VoiceYourText"
                info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
            },
            clearNowPlayingInfo: {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            },
            remoteCommandEvents: { stream }
        )
    }
}

extension NowPlayingClient: TestDependencyKey {
    static let testValue = Self()
}

extension DependencyValues {
    var nowPlayingClient: NowPlayingClient {
        get { self[NowPlayingClient.self] }
        set { self[NowPlayingClient.self] = newValue }
    }
}
