import Foundation
import Dependencies

/// キャラ音声の再生。本編の読み上げと設定画面の試聴で同じ再生器を使う（同時に2つ鳴らさない）。
struct VoicevoxPlayerClient: Sendable {
    /// 再生を始め、イベントを流す。finished / failed / quotaExceeded で終わる
    var play: @Sendable (_ text: String, _ speakerId: Int, _ speedScale: Double) async -> AsyncStream<VoicevoxSpeechPlayer.Event>
    var stop: @Sendable () async -> Void
}

extension VoicevoxPlayerClient: DependencyKey {
    @MainActor
    private static let player = VoicevoxSpeechPlayer(
        synthesize: { text, speakerId, speedScale in
            try await VoicevoxClient.liveValue.synthesize(text, speakerId, speedScale)
        },
        cache: .live,
        output: AVAudioPlayerOutput()
    )

    static let liveValue = Self(
        play: { text, speakerId, speedScale in
            await MainActor.run {
                AsyncStream { continuation in
                    player.play(text: text, speakerId: speakerId, speedScale: speedScale) { event in
                        continuation.yield(event)
                        switch event {
                        case .finished, .failed, .quotaExceeded:
                            continuation.finish()
                        case .sentence:
                            break
                        }
                    }
                    let generation = player.generation
                    continuation.onTermination = { termination in
                        // 受け取る側がやめた（停止ボタン・画面を閉じた等）ときは、この再生だけを止める。
                        // すでに次の再生が始まっていれば何もしない
                        if case .cancelled = termination {
                            Task { @MainActor in player.stop(generation: generation) }
                        }
                    }
                }
            }
        },
        stop: {
            await MainActor.run { player.stop() }
        }
    )

    static let testValue = Self(
        play: unimplemented("VoicevoxPlayerClient.play", placeholder: AsyncStream { $0.finish() }),
        stop: unimplemented("VoicevoxPlayerClient.stop")
    )
}

extension DependencyValues {
    var voicevoxPlayer: VoicevoxPlayerClient {
        get { self[VoicevoxPlayerClient.self] }
        set { self[VoicevoxPlayerClient.self] = newValue }
    }
}
