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

    /// NPZ（ZIP）エントリのパスから voice キーを取り出す。`.npy` で終わるエントリのみ
    /// 対象で、拡張子を除いた名前を返す（例: "af_heart.npy" → "af_heart"）。
    /// それ以外（ディレクトリ等）は nil。`KokoroEngine.loadVoicesNPZ` の
    /// エントリ→キー変換を、モデルロードに依存せずテストできるよう切り出したもの。
    static func npzEntryVoiceKey(fromPath path: String) -> String? {
        guard path.hasSuffix(".npy") else { return nil }
        return String(path.dropLast(4))
    }

    /// voices.npz から読み込めたキー集合に、期待する全 voice が含まれるか検証する。
    /// 欠けている `KokoroVoice` を宣言順で返す（空なら全 12 ボイス揃っている）。
    /// Issue #88: iOS 27 Beta で ZIPFoundation が全 12 ボイスを復元できることの
    /// 検証項目を、実機ダウンロードなしにチェックできるよう純粋関数化したもの。
    static func missingVoices(loadedKeys: Set<String>) -> [KokoroVoice] {
        KokoroVoice.allCases.filter { !loadedKeys.contains($0.rawValue) }
    }
}

// MARK: - Bundled resource lookup (config.json / MisakiSwift lexicon & BART)
//
// KokoroSwift/MisakiSwift were inlined into the main app target, so their bundled
// resources now live at the app-bundle root and are looked up via `Bundle.main`
// (previously `Bundle.module`, Issue #87). Centralizing the resource *names* here
// lets the lookup contract be regression-tested — a rename or a stray
// `subdirectory:` that breaks `Bundle.main.url(forResource:)` fails the test —
// without the ~600MB model or an on-device bundle.

enum KokoroBundleResource {

    /// KokoroTTS model config — `config.json` at the bundle root
    /// (`KokoroConfig.loadConfig()`).
    static let config = "config"

    /// Gold-tier English pronunciation lexicon (`us_gold` / `gb_gold`).
    static func gold(british: Bool) -> String { british ? "gb_gold" : "us_gold" }

    /// Silver-tier English pronunciation lexicon (`us_silver` / `gb_silver`).
    static func silver(british: Bool) -> String { british ? "gb_silver" : "us_silver" }

    /// English fallback BART model config (`us_bart_config` / `gb_bart_config`).
    static func bartConfig(british: Bool) -> String { british ? "gb_bart_config" : "us_bart_config" }

    /// English fallback BART model weights (`us_bart` / `gb_bart`, `.safetensors`).
    static func bartWeights(british: Bool) -> String { british ? "gb_bart" : "us_bart" }
}

enum MisakiLexicon {

    /// Parse a gold/silver lexicon payload into a `[grapheme: phoneme]` dictionary.
    /// Returns an empty dictionary when the data is missing or malformed, mirroring
    /// `DataResourcesUtil`'s fail-safe fallback so a lookup miss never crashes.
    static func parse(_ data: Data?) -> [String: Any] {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return [:] }
        return json
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

// MARK: - Linkage regression guard (Issue #86: iOS 27 Beta dyld クラッシュ修正の維持)
//
// KokoroSwift / MisakiSwift は commit 2bc7e5d でメインターゲットにインライン化され、
// dynamic framework の埋め込みは完全に除去された（iOS 27 Beta で dyld の
// `xpc_create_from_plist_with_string_cache` を通じてクラッシュしていたため）。
//
// 以下のパターンがソースに再混入するとクラッシュが再発する:
//   - `import KokoroSwift` / `import MisakiSwift`
//       → 削除済みの dynamic framework を dyld がロードしようとして
//         `Library not loaded: @rpath/MisakiSwift.framework/MisakiSwift` で起動時クラッシュ
//   - `Bundle.module`
//       → インライン化コードには SPM の `Bundle.module` が合成されないため参照するとクラッシュ
//         （Bundle.main への移行は Issue #87）
//
// 実機（iOS 27 Beta）でしか観測できないクラッシュそのものは自動化できないが、
// 「再発を招くソースパターンが混入していないか」は純粋関数として回帰検証できる。
enum KokoroLinkageGuard {

    /// import すると削除済み dynamic framework を要求してしまうモジュール名。
    static let forbiddenImportedModules = ["KokoroSwift", "MisakiSwift"]

    /// インライン化コードでは合成されず、参照するとクラッシュするバンドルアクセサ。
    static let forbiddenBundleAccessor = "Bundle.module"

    /// Swift ソース文字列を走査し、Issue #86 のクラッシュを再発させる禁止パターンを
    /// 出現順（重複あり）で返す。行コメント（`//` 以降）は無視するので、ドキュメント中で
    /// パターンに言及していても誤検出しない。空配列なら禁止パターンなし。
    static func forbiddenLinkage(in source: String) -> [String] {
        var found: [String] = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            // 行コメントを取り除いてコード部分だけを対象にする。
            let code = String(rawLine.split(separator: "//", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")

            for module in forbiddenImportedModules {
                // `import KokoroSwift` / `@_implementationOnly import KokoroSwift` /
                // `import KokoroSwift.SubModule` は検出するが、`importKokoroSwift`（空白なし）は対象外。
                let pattern = #"(?:^|\W)import\s+"# + NSRegularExpression.escapedPattern(for: module) + #"(?:\b|$)"#
                if code.range(of: pattern, options: .regularExpression) != nil {
                    found.append("import \(module)")
                }
            }

            if code.contains(forbiddenBundleAccessor) {
                found.append(forbiddenBundleAccessor)
            }
        }
        return found
    }
}
