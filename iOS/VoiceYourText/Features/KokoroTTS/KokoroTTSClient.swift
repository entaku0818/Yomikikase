import Foundation
import ComposableArchitecture
import AVFoundation

// MARK: - Voice character metadata

enum VoiceGender {
    case female, male
    var label: String { self == .female ? "女性" : "男性" }
    var systemImage: String { self == .female ? "figure.stand.dress" : "figure.stand" }
}

enum VoiceAccent {
    case american, british, japanese
    var label: String {
        switch self {
        case .american: return "🇺🇸 US英語"
        case .british:  return "🇬🇧 UK英語"
        case .japanese: return "🇯🇵 日本語"
        }
    }
}

// MARK: - Voice definitions

enum KokoroVoice: String, CaseIterable, Identifiable {
    // English (US Female)
    case afHeart    = "af_heart"
    case afBella    = "af_bella"
    case afNicole   = "af_nicole"
    case afSarah    = "af_sarah"
    // English (US Male)
    case amAdam     = "am_adam"
    case amMichael  = "am_michael"
    // English (UK Female)
    case bfEmma     = "bf_emma"
    case bfIsabella = "bf_isabella"
    // English (UK Male)
    case bmGeorge   = "bm_george"
    case bmLewis    = "bm_lewis"
    // Japanese
    case jfAlpha    = "jf_alpha"
    case jmKumo     = "jm_kumo"

    var id: String { rawValue }

    var isJapanese: Bool { rawValue.hasPrefix("j") }

    // MARK: Character properties

    var characterName: String {
        switch self {
        case .afHeart:    return "Heart"
        case .afBella:    return "Bella"
        case .afNicole:   return "Nicole"
        case .afSarah:    return "Sarah"
        case .amAdam:     return "Adam"
        case .amMichael:  return "Michael"
        case .bfEmma:     return "Emma"
        case .bfIsabella: return "Isabella"
        case .bmGeorge:   return "George"
        case .bmLewis:    return "Lewis"
        case .jfAlpha:    return "凛"
        case .jmKumo:     return "雲"
        }
    }

    var persona: String {
        switch self {
        case .afHeart:    return "温かみある声。親しみやすく日常会話向き"
        case .afBella:    return "優雅で落ち着いた声。ナレーション向き"
        case .afNicole:   return "知性的でハキハキした声。説明・講義向き"
        case .afSarah:    return "元気で明るい声。アナウンス・エンタメ向き"
        case .amAdam:     return "穏やかで誠実な声。語り・朗読向き"
        case .amMichael:  return "力強い低音。ドキュメンタリー向き"
        case .bfEmma:     return "品格ある英国アクセント。ビジネス向き"
        case .bfIsabella: return "柔らかで優しい声。教育コンテンツ向き"
        case .bmGeorge:   return "重厚で威厳ある声。フォーマル向き"
        case .bmLewis:    return "若々しく活発。カジュアルコンテンツ向き"
        case .jfAlpha:    return "落ち着いた知性的な声。あらゆる場面に"
        case .jmKumo:     return "穏やかで誠実な声。語りかけるように"
        }
    }

    var gender: VoiceGender {
        switch self {
        case .afHeart, .afBella, .afNicole, .afSarah,
             .bfEmma, .bfIsabella, .jfAlpha:
            return .female
        case .amAdam, .amMichael, .bmGeorge, .bmLewis, .jmKumo:
            return .male
        }
    }

    var accent: VoiceAccent {
        switch self {
        case .afHeart, .afBella, .afNicole, .afSarah,
             .amAdam, .amMichael:
            return .american
        case .bfEmma, .bfIsabella, .bmGeorge, .bmLewis:
            return .british
        case .jfAlpha, .jmKumo:
            return .japanese
        }
    }

    var displayName: String { characterName }

    var sampleText: String {
        isJapanese
            ? "こんにちは。私の声はいかがですか？"
            : "Hello! How does my voice sound to you?"
    }

    static var `default`: KokoroVoice { .afHeart }
    static var defaultJapanese: KokoroVoice { .jfAlpha }
}

// MARK: - TCA Dependency

@DependencyClient
struct KokoroTTSClient {
    /// モデルDL済み + iOS 18+ のとき true
    var isAvailable: @Sendable () -> Bool = { false }
    /// テキスト → WAV Data（24kHz mono）
    var synthesize: @Sendable (_ text: String, _ voice: KokoroVoice, _ speed: Float) async throws -> Data
}

enum KokoroError: LocalizedError {
    case modelNotDownloaded
    case unavailable
    case packageNotInstalled
    case synthesisFailure(String)

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:      return "Kokoroモデルがダウンロードされていません"
        case .unavailable:             return "iOS 18以上が必要です"
        case .packageNotInstalled:     return "KokoroSwiftパッケージが追加されていません"
        case .synthesisFailure(let m): return "音声合成失敗: \(m)"
        }
    }
}

extension KokoroTTSClient: DependencyKey {
    static var liveValue: Self {
        Self(
            isAvailable: {
                KokoroModelManager.checkDownloaded()
            },
            synthesize: { text, voice, speed in
                return try await KokoroEngine.shared.synthesize(
                    text: text, voice: voice, speed: speed
                )
            }
        )
    }
}

extension DependencyValues {
    var kokoroTTS: KokoroTTSClient {
        get { self[KokoroTTSClient.self] }
        set { self[KokoroTTSClient.self] = newValue }
    }
}

// MARK: - Kokoro Engine (モデルキャッシュ付き)

import MLX
import ZIPFoundation

actor KokoroEngine {
    static let shared = KokoroEngine()

    private var ttsEnglish: KokoroTTS?
    private var ttsJapanese: KokoroTTS?
    private var voices: [String: MLXArray]?

    // 同一言語の初回ロードが並行して走っても二重ロード（≒600MB×2）にならないよう
    // 進行中のロード Task をキャッシュして共有する。
    private var englishLoadTask: Task<KokoroTTS, Error>?
    private var japaneseLoadTask: Task<KokoroTTS, Error>?

    func synthesize(text: String, voice: KokoroVoice, speed: Float) async throws -> Data {
        guard KokoroModelManager.checkDownloaded(),
              let modelURL  = await KokoroModelManager.shared.modelFileURL(),
              let voicesURL = await KokoroModelManager.shared.voicesFileURL()
        else { throw KokoroError.modelNotDownloaded }

        // 初回のみロード（重い処理）。約600MBのモデル読み込み＋複数NNの構築は
        // メインスレッド・アクターのエグゼキュータを塞がないよう detached Task で実行する。
        let tts: KokoroTTS
        if voice.isJapanese {
            tts = try await loadJapaneseTTS(modelURL: modelURL)
        } else {
            tts = try await loadEnglishTTS(modelURL: modelURL)
        }
        if voices == nil {
            voices = try loadVoicesNPZ(url: voicesURL)
        }

        // keys are stored WITHOUT ".npy" (loadVoicesNPZ strips the extension)
        guard let voiceEmbedding = voices?[voice.rawValue] else {
            throw KokoroError.synthesisFailure("Voice '\(voice.rawValue)' not found in voices.npz")
        }

        let language: Language = voice.isJapanese ? .ja : .enUS

        let (samples, _) = try tts.generateAudio(
            voice: voiceEmbedding,
            language: language,
            text: text,
            speed: speed
        )

        return try pcmToWAV(samples: samples, sampleRate: 24000)
    }

    // MARK: - モデルロード（off-main / 二重ロード防止）

    private func loadEnglishTTS(modelURL: URL) async throws -> KokoroTTS {
        if let tts = ttsEnglish {
            return tts
        }
        if let task = englishLoadTask {
            return try await task.value
        }
        let task = Task.detached(priority: .userInitiated) {
            try KokoroTTS(modelPath: modelURL, g2p: .misaki)
        }
        englishLoadTask = task
        defer { englishLoadTask = nil }
        do {
            let tts = try await task.value
            ttsEnglish = tts
            return tts
        } catch {
            throw KokoroError.synthesisFailure("モデルの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }

    private func loadJapaneseTTS(modelURL: URL) async throws -> KokoroTTS {
        if let tts = ttsJapanese {
            return tts
        }
        if let task = japaneseLoadTask {
            return try await task.value
        }
        let task = Task.detached(priority: .userInitiated) {
            try KokoroTTS(modelPath: modelURL, g2p: .japanese)
        }
        japaneseLoadTask = task
        defer { japaneseLoadTask = nil }
        do {
            let tts = try await task.value
            ttsJapanese = tts
            return tts
        } catch {
            throw KokoroError.synthesisFailure("モデルの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }

    // NPZ（ZIP of NPY files）を読み込み MLXArray の辞書を返す
    private func loadVoicesNPZ(url: URL) throws -> [String: MLXArray] {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw KokoroError.synthesisFailure("Cannot open voices.npz")
        }
        var result: [String: MLXArray] = [:]
        for entry in archive where entry.path.hasSuffix(".npy") {
            let key = String(entry.path.dropLast(4))
            var data = Data()
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
            if let array = parseNPY(data) {
                result[key] = array
            }
        }
        return result
    }

    // NPY バイナリ → MLXArray（Float32 のみ対応）
    private func parseNPY(_ data: Data) -> MLXArray? {
        let magic: [UInt8] = [0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59]
        guard data.count > 10, data.prefix(6) == Data(magic) else { return nil }

        let majorVer = data[6]
        let headerLen: Int
        let dataStart: Int
        if majorVer == 1 {
            headerLen = Int(data[8]) | (Int(data[9]) << 8)
            dataStart = 10 + headerLen
        } else {
            headerLen = Int(data[8]) | (Int(data[9]) << 8) | (Int(data[10]) << 16) | (Int(data[11]) << 24)
            dataStart = 12 + headerLen
        }
        guard dataStart <= data.count else { return nil }

        let headerBytes = data[10..<min(10 + headerLen, data.count)]
        let header = String(bytes: headerBytes, encoding: .utf8) ?? ""
        let shape = parseNPYShape(from: header)

        let floats = data[dataStart...].withUnsafeBytes { ptr -> [Float] in
            Array(ptr.bindMemory(to: Float.self))
        }
        return shape.isEmpty ? MLXArray(floats) : MLXArray(floats, shape)
    }

    private func parseNPYShape(from header: String) -> [Int] {
        guard let start = header.range(of: "'shape': ("),
              let end = header.range(of: ")", range: start.upperBound..<header.endIndex)
        else { return [] }
        return String(header[start.upperBound..<end.lowerBound])
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    // [Float] (24kHz mono) → WAV Data
    private func pcmToWAV(samples: [Float], sampleRate: Int) throws -> Data {
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
}
