import AVFoundation
import Foundation

/// 音声データを鳴らす先。テストでは偽物に差し替える。
@MainActor
protocol VoicevoxAudioOutput: AnyObject {
    /// data を最後まで再生したら返る。Task がキャンセルされたら再生を止めて CancellationError を投げる
    func play(_ data: Data) async throws
    func stop()
}

/// キャラ音声（VOICEVOX）で文章を読み上げる。
///
/// 文ごとにサーバーで音声を作り、1文目ができた時点で再生を始める。再生中に次の文を先に作っておくので、
/// 生成が再生より速ければ（Cloud Run 実測で音声1秒あたり約0.5秒）文の間で待たない。
/// 作った音声は端末に保存し、同じ文・声・速度なら保存済みを使う。
@MainActor
final class VoicevoxSpeechPlayer {
    enum Event: Equatable {
        /// この文の再生を始めた（元の文章の中の位置）。ハイライトに使う
        case sentence(NSRange)
        /// 最後まで読んだ
        case finished
        /// 今月の上限に達した。resumeAt（元の文章の UTF-16 位置）から先は読めていない
        case quotaExceeded(VoicevoxUsage, resumeAt: Int)
        /// 通信エラーなどで止まった。resumeAt から先を端末の音声で読み直せる
        case failed(resumeAt: Int)
    }

    typealias Synthesize = @Sendable (_ text: String, _ speakerId: Int, _ speedScale: Double) async throws -> VoicevoxAudio

    private let synthesize: Synthesize
    private let cache: VoicevoxAudioCache?
    private let output: VoicevoxAudioOutput
    private var task: Task<Void, Never>?
    private var prefetch: Task<Data, Error>?

    init(synthesize: @escaping Synthesize, cache: VoicevoxAudioCache?, output: VoicevoxAudioOutput) {
        self.synthesize = synthesize
        self.cache = cache
        self.output = output
    }

    var isPlaying: Bool { task != nil }

    /// 再生のたびに増える番号。古い再生に対する停止が、新しい再生を止めてしまわないようにする
    private(set) var generation = 0

    func play(text: String, speakerId: Int, speedScale: Double, onEvent: @escaping @MainActor (Event) -> Void) {
        stop()
        generation += 1
        let current = generation
        let chunks = VoicevoxTextChunker.chunks(from: text)
        task = Task { [weak self] in
            await self?.run(chunks: chunks, speakerId: speakerId, speedScale: speedScale, onEvent: onEvent)
            if self?.generation == current {
                self?.task = nil
            }
        }
    }

    /// generation を渡したときは、その再生がまだ続いている場合だけ止める
    func stop(generation target: Int? = nil) {
        if let target, target != generation { return }
        task?.cancel()
        task = nil
        prefetch?.cancel()
        prefetch = nil
        output.stop()
    }

    private func run(chunks: [VoicevoxTextChunker.Chunk], speakerId: Int, speedScale: Double, onEvent: @MainActor (Event) -> Void) async {
        guard !chunks.isEmpty else {
            onEvent(.finished)
            return
        }
        prefetch = audio(for: chunks[0], speakerId: speakerId, speedScale: speedScale)

        for index in chunks.indices {
            guard let pending = prefetch else { return }
            let data: Data
            do {
                data = try await pending.value
            } catch is CancellationError {
                return
            } catch VoicevoxError.quotaExceeded(let usage) {
                prefetch = nil
                onEvent(.quotaExceeded(usage, resumeAt: chunks[index].range.location))
                return
            } catch {
                if Task.isCancelled { return }
                errorLog("[VOICEVOX] synthesis failed at chunk \(index): \(error)")
                prefetch = nil
                onEvent(.failed(resumeAt: chunks[index].range.location))
                return
            }
            if Task.isCancelled { return }

            // 再生している間に次の文を作っておく
            let nextIndex = index + 1
            prefetch = nextIndex < chunks.count
                ? audio(for: chunks[nextIndex], speakerId: speakerId, speedScale: speedScale)
                : nil

            onEvent(.sentence(chunks[index].range))
            do {
                try await output.play(data)
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                // 壊れた音声などで再生できなかったときは、その文から端末の音声で読み直す
                errorLog("[VOICEVOX] playback failed at chunk \(index): \(error)")
                prefetch?.cancel()
                prefetch = nil
                onEvent(.failed(resumeAt: chunks[index].range.location))
                return
            }
        }
        if !Task.isCancelled {
            onEvent(.finished)
        }
    }

    private func audio(for chunk: VoicevoxTextChunker.Chunk, speakerId: Int, speedScale: Double) -> Task<Data, Error> {
        let synthesize = synthesize
        let cache = cache
        return Task {
            if let cached = cache?.load(text: chunk.text, speakerId: speakerId, speedScale: speedScale) {
                return cached
            }
            let audio = try await synthesize(chunk.text, speakerId, speedScale)
            try Task.checkCancellation()
            cache?.store(audio.data, text: chunk.text, speakerId: speakerId, speedScale: speedScale)
            return audio.data
        }
    }
}

/// AVAudioPlayer で鳴らす。
@MainActor
final class AVAudioPlayerOutput: NSObject, VoicevoxAudioOutput, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?

    func play(_ data: Data) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    let player = try AVAudioPlayer(data: data)
                    player.delegate = self
                    self.player = player
                    self.continuation = continuation
                    if !player.play() {
                        finish(with: VoicevoxPlaybackError.couldNotStart)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(with: CancellationError()) }
        }
    }

    func stop() {
        finish(with: CancellationError())
    }

    private func finish(with error: Error?) {
        player?.stop()
        player = nil
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.finish(with: flag ? nil : VoicevoxPlaybackError.interrupted)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.finish(with: error ?? VoicevoxPlaybackError.interrupted)
        }
    }
}

enum VoicevoxPlaybackError: Error {
    case couldNotStart
    case interrupted
}
