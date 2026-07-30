import Foundation

// MARK: - Pure, MLX-free helpers for Kokoro TTS
//
// The audio/format logic and playback-parameter selection are extracted here so
// they can be unit-tested without loading the ~600MB MLX model. `KokoroEngine`
// (the actor in KokoroTTSClient.swift) and `TextInputView` delegate to these,
// so the tests exercise the real production code path.

enum KokoroAudioUtil {

    /// `[Float]` (mono PCM, expected range -1.0...1.0) → 16-bit little-endian WAV `Data`.
    /// Samples are clamped to [-1.0, 1.0] before quantization to Int16.
    static func pcmToWAV(samples: [Float], sampleRate: Int) -> Data {
        let channelCount: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * (bitsPerSample / 8)
        let pcmSamples = samples.map { s -> Int16 in
            Int16(max(-1.0, min(1.0, s)) * Float(Int16.max))
        }
        let dataSize = UInt32(pcmSamples.count * 2)

        var wav = Data()
        func write<T: FixedWidthInteger>(_ v: T) {
            withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) }
        }
        wav.append(contentsOf: "RIFF".utf8); write(UInt32(36 + dataSize))
        wav.append(contentsOf: "WAVEfmt ".utf8); write(UInt32(16))
        write(UInt16(1)); write(channelCount)
        write(UInt32(sampleRate)); write(byteRate)
        write(blockAlign); write(bitsPerSample)
        wav.append(contentsOf: "data".utf8); write(dataSize)
        for s in pcmSamples { write(s) }
        return wav
    }

    /// Parse the `'shape': (...)` tuple out of an NPY header string.
    /// Returns an empty array for scalars or malformed headers.
    static func parseNPYShape(from header: String) -> [Int] {
        guard let start = header.range(of: "'shape': ("),
              let end = header.range(of: ")", range: start.upperBound..<header.endIndex)
        else { return [] }
        return String(header[start.upperBound..<end.lowerBound])
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Look up a voice embedding by raw value, throwing `synthesisFailure` when absent.
    /// Generic over the value type so it can be tested without depending on MLXArray.
    static func voiceEmbedding<T>(from voices: [String: T], voiceRawValue: String) throws -> T {
        guard let embedding = voices[voiceRawValue] else {
            throw KokoroError.synthesisFailure("Voice '\(voiceRawValue)' not found in voices.npz")
        }
        return embedding
    }
}

// MARK: - Playback parameter selection (used by TextInputView)

enum KokoroPlaybackParams {

    /// Kokoro should be used only when the model is available AND the user enabled it.
    static func shouldUseKokoro(available: Bool, enabled: Bool) -> Bool {
        available && enabled
    }

    /// Default voice for a language code ("ja*" → Japanese default, otherwise US default),
    /// overridden by a stored raw value when it maps to a known voice.
    static func selectVoice(languageCode: String?, storedVoiceRaw: String?) -> KokoroVoice {
        let isJapanese = (languageCode ?? "ja").hasPrefix("ja")
        let defaultVoice: KokoroVoice = isJapanese ? .defaultJapanese : .default
        guard let raw = storedVoiceRaw else { return defaultVoice }
        return KokoroVoice(rawValue: raw) ?? defaultVoice
    }

    /// AVSpeechSynthesizer rate (0.5 = normal) → Kokoro speed (1.0 = normal),
    /// clamped to Kokoro's supported [0.5, 2.0] range.
    static func kokoroSpeed(fromSpeechRate speechRate: Float) -> Float {
        max(0.5, min(2.0, speechRate * 2.0))
    }

    /// AVSpeechSynthesizer rate (0.5 = normal) → AVAudioPlayer rate (1.0 = normal),
    /// clamped to AVAudioPlayer's supported [0.5, 2.0] range.
    /// Cloud TTS / Kokoro の再生速度計算を一元化するための共通ヘルパー。
    static func avPlaybackRate(fromSpeechRate speechRate: Float) -> Float {
        max(0.5, min(2.0, speechRate * 2.0))
    }
}
