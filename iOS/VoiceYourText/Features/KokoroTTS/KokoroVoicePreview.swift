import AVFoundation
import Combine
import Foundation

/// One preview session per picker; changing voices or leaving cancels synthesis and audio.
@MainActor
final class KokoroVoicePreview: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var voice: KokoroVoice?
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?
    private var player: AVAudioPlayer?
    private(set) var task: Task<Void, Never>?
    private var generation = UUID()
    private let synthesize: @Sendable (String, KokoroVoice, Float) async throws -> Data

    init(synthesize: @escaping @Sendable (String, KokoroVoice, Float) async throws -> Data = KokoroTTSClient.liveValue.synthesize) {
        self.synthesize = synthesize
    }

    func toggle(_ requestedVoice: KokoroVoice) {
        if voice == requestedVoice {
            stop()
            return
        }
        stop()
        errorMessage = nil
        voice = requestedVoice
        isGenerating = true
        let token = generation
        task = Task { [weak self, synthesize] in
            do {
                let data = try await synthesize(requestedVoice.sampleText, requestedVoice, 1)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio)
                try session.setActive(true)
                let audio = try AVAudioPlayer(data: data)
                audio.delegate = self
                self.player = audio
                self.isGenerating = false
                guard audio.play() else { throw KokoroError.synthesisFailure("Audio playback failed") }
            } catch is CancellationError {
                // A newer voice or leaving the picker owns the UI now.
            } catch {
                guard let self, self.generation == token else { return }
                self.stop()
                self.errorMessage = String(localized: "音声を再生できませんでした。もう一度お試しください。")
            }
        }
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        player?.stop()
        player = nil
        voice = nil
        isGenerating = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.stop()
        }
    }
}
