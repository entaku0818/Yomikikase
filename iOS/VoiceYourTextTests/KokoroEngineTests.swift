//
//  KokoroEngineTests.swift
//  VoiceYourTextTests
//
//  QA: Kokoro ローカル音声機能のユニットテスト (Issue #99)
//  カバレッジ:
//   - KokoroAudioUtil.pcmToWAV : クリッピング境界値 / サンプル数→dataSize / WAVヘッダ
//   - KokoroAudioUtil.parseNPYShape : NPYヘッダ文字列パース
//   - KokoroAudioUtil.voiceEmbedding : voice 未存在時の synthesisFailure
//   - KokoroPlaybackParams : 言語別デフォルトvoice選択 / speed境界値 / kokoro使用判定

import XCTest
@testable import VoiceYourText

final class KokoroEngineTests: XCTestCase {

    // MARK: - pcmToWAV: WAV ヘッダ / dataSize

    /// 44バイトの標準WAVヘッダ（RIFF/WAVE/fmt/data）が正しく組み立てられる
    func test_pcmToWAV_header_isValidRIFFWave() {
        let wav = KokoroAudioUtil.pcmToWAV(samples: [0.0, 0.0], sampleRate: 24000)

        // ヘッダ44バイト + サンプル2個×2バイト = 48バイト
        XCTAssertEqual(wav.count, 48)
        XCTAssertEqual(String(bytes: wav[0..<4], encoding: .ascii), "RIFF")
        XCTAssertEqual(String(bytes: wav[8..<12], encoding: .ascii), "WAVE")
        XCTAssertEqual(String(bytes: wav[12..<16], encoding: .ascii), "fmt ")
        XCTAssertEqual(String(bytes: wav[36..<40], encoding: .ascii), "data")
    }

    /// dataSize (data チャンク長) は サンプル数 × 2バイト
    func test_pcmToWAV_dataSize_isSampleCountTimesTwo() {
        let samples = [Float](repeating: 0.0, count: 100)
        let wav = KokoroAudioUtil.pcmToWAV(samples: samples, sampleRate: 24000)

        // data チャンクサイズは offset 40 から 4バイト (little-endian)
        let dataSize = readUInt32LE(wav, at: 40)
        XCTAssertEqual(dataSize, 200) // 100 samples * 2 bytes

        // RIFF チャンクサイズ (offset 4) は 36 + dataSize
        let riffSize = readUInt32LE(wav, at: 4)
        XCTAssertEqual(riffSize, 36 + 200)

        XCTAssertEqual(wav.count, 44 + 200)
    }

    /// 空サンプルでも 44バイトのヘッダのみが返る
    func test_pcmToWAV_emptySamples_returnsHeaderOnly() {
        let wav = KokoroAudioUtil.pcmToWAV(samples: [], sampleRate: 24000)
        XCTAssertEqual(wav.count, 44)
        XCTAssertEqual(readUInt32LE(wav, at: 40), 0)
    }

    /// sampleRate はヘッダの offset 24 に little-endian で書かれる
    func test_pcmToWAV_sampleRate_isWrittenToHeader() {
        let wav = KokoroAudioUtil.pcmToWAV(samples: [0.0], sampleRate: 24000)
        XCTAssertEqual(readUInt32LE(wav, at: 24), 24000)
        // byteRate = sampleRate * channels(1) * bytesPerSample(2)
        XCTAssertEqual(readUInt32LE(wav, at: 28), 24000 * 2)
    }

    // MARK: - pcmToWAV: クリッピング境界値

    /// +1.0 は Int16.max (32767) にクリップ量子化される
    func test_pcmToWAV_clipsUpperBound_toInt16Max() {
        let wav = KokoroAudioUtil.pcmToWAV(samples: [2.0], sampleRate: 24000) // 範囲外 +2.0
        let sample = readInt16LE(wav, at: 44)
        XCTAssertEqual(sample, 32767)
    }

    /// -1.0 (およびそれ以下) は -32767 にクリップ量子化される
    func test_pcmToWAV_clipsLowerBound() {
        let wav = KokoroAudioUtil.pcmToWAV(samples: [-2.0], sampleRate: 24000) // 範囲外 -2.0
        let sample = readInt16LE(wav, at: 44)
        // max(-1.0, min(1.0, -2.0)) = -1.0 → -1.0 * 32767 = -32767
        XCTAssertEqual(sample, -32767)
    }

    /// 0.0 は無音 (0) になる
    func test_pcmToWAV_zeroSample_isSilence() {
        let wav = KokoroAudioUtil.pcmToWAV(samples: [0.0], sampleRate: 24000)
        XCTAssertEqual(readInt16LE(wav, at: 44), 0)
    }

    // MARK: - parseNPYShape

    func test_parseNPYShape_1D_shape() {
        let header = "{'descr': '<f4', 'fortran_order': False, 'shape': (256,), }"
        XCTAssertEqual(KokoroAudioUtil.parseNPYShape(from: header), [256])
    }

    func test_parseNPYShape_2D_shape() {
        let header = "{'descr': '<f4', 'fortran_order': False, 'shape': (510, 256), }"
        XCTAssertEqual(KokoroAudioUtil.parseNPYShape(from: header), [510, 256])
    }

    func test_parseNPYShape_scalar_emptyShape() {
        let header = "{'descr': '<f4', 'fortran_order': False, 'shape': (), }"
        XCTAssertEqual(KokoroAudioUtil.parseNPYShape(from: header), [])
    }

    func test_parseNPYShape_malformedHeader_returnsEmpty() {
        XCTAssertEqual(KokoroAudioUtil.parseNPYShape(from: "no shape here"), [])
    }

    // MARK: - voiceEmbedding (voice未存在時の synthesisFailure)

    func test_voiceEmbedding_existingVoice_returnsValue() throws {
        let voices = ["af_heart": 42, "jf_alpha": 7]
        let value = try KokoroAudioUtil.voiceEmbedding(from: voices, voiceRawValue: "af_heart")
        XCTAssertEqual(value, 42)
    }

    func test_voiceEmbedding_missingVoice_throwsSynthesisFailure() {
        let voices = ["af_heart": 42]
        XCTAssertThrowsError(
            try KokoroAudioUtil.voiceEmbedding(from: voices, voiceRawValue: "unknown_voice")
        ) { error in
            guard let kokoroError = error as? KokoroError,
                  case let .synthesisFailure(message) = kokoroError else {
                XCTFail("Expected KokoroError.synthesisFailure, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("unknown_voice"))
        }
    }

    func test_voiceEmbedding_emptyDictionary_throws() {
        let voices: [String: Int] = [:]
        XCTAssertThrowsError(
            try KokoroAudioUtil.voiceEmbedding(from: voices, voiceRawValue: "af_heart")
        )
    }

    // MARK: - KokoroPlaybackParams.shouldUseKokoro

    func test_shouldUseKokoro_bothTrue_isTrue() {
        XCTAssertTrue(KokoroPlaybackParams.shouldUseKokoro(available: true, enabled: true))
    }

    func test_shouldUseKokoro_availableButDisabled_isFalse() {
        XCTAssertFalse(KokoroPlaybackParams.shouldUseKokoro(available: true, enabled: false))
    }

    func test_shouldUseKokoro_enabledButUnavailable_isFalse() {
        XCTAssertFalse(KokoroPlaybackParams.shouldUseKokoro(available: false, enabled: true))
    }

    // MARK: - KokoroPlaybackParams.selectVoice (言語別デフォルト)

    func test_selectVoice_japaneseLanguage_noStored_usesJapaneseDefault() {
        let voice = KokoroPlaybackParams.selectVoice(languageCode: "ja-JP", storedVoiceRaw: nil)
        XCTAssertEqual(voice, KokoroVoice.defaultJapanese)
    }

    func test_selectVoice_englishLanguage_noStored_usesUSDefault() {
        let voice = KokoroPlaybackParams.selectVoice(languageCode: "en-US", storedVoiceRaw: nil)
        XCTAssertEqual(voice, KokoroVoice.default)
    }

    func test_selectVoice_nilLanguage_defaultsToJapanese() {
        // 実装は言語未設定を "ja" とみなす
        let voice = KokoroPlaybackParams.selectVoice(languageCode: nil, storedVoiceRaw: nil)
        XCTAssertEqual(voice, KokoroVoice.defaultJapanese)
    }

    func test_selectVoice_validStoredVoice_isRespected() {
        let voice = KokoroPlaybackParams.selectVoice(languageCode: "ja-JP", storedVoiceRaw: "am_adam")
        XCTAssertEqual(voice, .amAdam)
    }

    func test_selectVoice_invalidStoredVoice_fallsBackToLanguageDefault() {
        let voice = KokoroPlaybackParams.selectVoice(languageCode: "en-US", storedVoiceRaw: "bogus_voice")
        XCTAssertEqual(voice, KokoroVoice.default)
    }

    // MARK: - KokoroPlaybackParams.kokoroSpeed (境界値)

    func test_kokoroSpeed_normalRate_doublesTo1() {
        // AVSpeech 0.5 (通常) → Kokoro 1.0
        XCTAssertEqual(KokoroPlaybackParams.kokoroSpeed(fromSpeechRate: 0.5), 1.0, accuracy: 0.0001)
    }

    func test_kokoroSpeed_clampsUpperBoundTo2() {
        // speechRate 1.0 → 2.0（上限）, さらに大きくても 2.0 でクランプ
        XCTAssertEqual(KokoroPlaybackParams.kokoroSpeed(fromSpeechRate: 1.0), 2.0, accuracy: 0.0001)
        XCTAssertEqual(KokoroPlaybackParams.kokoroSpeed(fromSpeechRate: 5.0), 2.0, accuracy: 0.0001)
    }

    func test_kokoroSpeed_clampsLowerBoundTo0_5() {
        // speechRate 0.1 → 0.2 だが下限 0.5 でクランプ
        XCTAssertEqual(KokoroPlaybackParams.kokoroSpeed(fromSpeechRate: 0.1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(KokoroPlaybackParams.kokoroSpeed(fromSpeechRate: 0.0), 0.5, accuracy: 0.0001)
    }

    // MARK: - KokoroPlaybackParams.avPlaybackRate (AVAudioPlayer 再生速度・境界値)

    func test_avPlaybackRate_normalRate_doublesTo1() {
        // AVSpeech 0.5 (通常) → AVAudioPlayer 1.0
        XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: 0.5), 1.0, accuracy: 0.0001)
    }

    func test_avPlaybackRate_clampsUpperBoundTo2() {
        // speechRate 1.0 → 2.0（上限）, さらに大きくても 2.0 でクランプ
        XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: 1.0), 2.0, accuracy: 0.0001)
        XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: 5.0), 2.0, accuracy: 0.0001)
    }

    func test_avPlaybackRate_clampsLowerBoundTo0_5() {
        // speechRate 0.1 → 0.2 だが下限 0.5 でクランプ
        XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: 0.1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: 0.0), 0.5, accuracy: 0.0001)
    }

    // MARK: - KokoroModelManager.isValidVoicesHeader (DL判定 / LFSポインタ検出)
    // Issue #89: モデルDL完了後に isAvailable(=checkDownloaded) が true を返す根拠となる
    // voices.npz の ZIP マジックバイト検証。GitHub LFS ポインタ誤保存時は false になる。

    /// ZIP マジックバイト (PK\x03\x04) で始まれば有効
    func test_isValidVoicesHeader_zipMagic_isValid() {
        let header = Data([0x50, 0x4B, 0x03, 0x04])
        XCTAssertTrue(KokoroModelManager.isValidVoicesHeader(header))
    }

    /// GitHub LFS ポインタ (テキスト "version ...") は無効
    func test_isValidVoicesHeader_lfsPointerText_isInvalid() {
        let header = Data("version https://git-lfs".utf8)
        XCTAssertFalse(KokoroModelManager.isValidVoicesHeader(header))
    }

    /// 2バイト未満 / nil は無効
    func test_isValidVoicesHeader_tooShortOrNil_isInvalid() {
        XCTAssertFalse(KokoroModelManager.isValidVoicesHeader(Data([0x50])))
        XCTAssertFalse(KokoroModelManager.isValidVoicesHeader(Data()))
        XCTAssertFalse(KokoroModelManager.isValidVoicesHeader(nil))
    }

    /// PK 始まりでない 4バイト (例: NPY マジック) は無効
    func test_isValidVoicesHeader_nonZipBytes_isInvalid() {
        let header = Data([0x93, 0x4E, 0x55, 0x4D]) // NPY マジックの一部
        XCTAssertFalse(KokoroModelManager.isValidVoicesHeader(header))
    }

    // MARK: - KokoroVoice 言語ルーティング (英語→enUS / 日本語→ja)
    // Issue #89: synthesize() は voice.isJapanese で日本語/英語モデルロードと
    // Language(.ja / .enUS) を分岐する。その分岐入力を検証する。

    func test_kokoroVoice_englishVoices_routeToEnglish() {
        for voice in [KokoroVoice.afHeart, .amAdam, .bfEmma, .bmLewis] {
            XCTAssertFalse(voice.isJapanese, "\(voice.rawValue) は英語ルートであるべき")
        }
        XCTAssertEqual(KokoroVoice.afHeart.accent, .american)
        XCTAssertEqual(KokoroVoice.bfEmma.accent, .british)
    }

    func test_kokoroVoice_japaneseVoices_routeToJapanese() {
        XCTAssertTrue(KokoroVoice.jfAlpha.isJapanese)
        XCTAssertTrue(KokoroVoice.jmKumo.isJapanese)
        XCTAssertEqual(KokoroVoice.jfAlpha.accent, .japanese)
        XCTAssertEqual(KokoroVoice.jmKumo.accent, .japanese)
    }

    /// 言語別デフォルト voice が正しい言語ルートに乗る
    func test_kokoroVoice_defaults_matchLanguageRoute() {
        XCTAssertFalse(KokoroVoice.default.isJapanese)          // .afHeart → 英語
        XCTAssertTrue(KokoroVoice.defaultJapanese.isJapanese)   // .jfAlpha → 日本語
    }

    // MARK: - npzEntryVoiceKey (NPZ エントリパス → voice キー変換)
    // Issue #88: loadVoicesNPZ の「.npy エントリのみ拾い拡張子を除いてキー化する」
    // ロジックを検証。ZIP 内に混在する非 .npy エントリを取りこぼさず除外できること。

    func test_npzEntryVoiceKey_npySuffix_stripsExtension() {
        XCTAssertEqual(KokoroAudioUtil.npzEntryVoiceKey(fromPath: "af_heart.npy"), "af_heart")
        XCTAssertEqual(KokoroAudioUtil.npzEntryVoiceKey(fromPath: "jf_alpha.npy"), "jf_alpha")
    }

    func test_npzEntryVoiceKey_nonNpyEntry_returnsNil() {
        XCTAssertNil(KokoroAudioUtil.npzEntryVoiceKey(fromPath: "af_heart"))
        XCTAssertNil(KokoroAudioUtil.npzEntryVoiceKey(fromPath: "voices/"))
        XCTAssertNil(KokoroAudioUtil.npzEntryVoiceKey(fromPath: "README.txt"))
    }

    // MARK: - missingVoices (全12ボイス復元チェック)
    // Issue #88: iOS 27 Beta で ZIPFoundation が全 12 voice キーを復元できることの
    // 検証。実機DL(約600MB)なしに「欠けたボイスを検出できる」ことをユニットで担保する。

    /// 期待する 12 voice が全て揃っていれば欠損なし
    func test_missingVoices_allPresent_isEmpty() {
        let loaded = Set(KokoroVoice.allCases.map(\.rawValue))
        XCTAssertTrue(KokoroAudioUtil.missingVoices(loadedKeys: loaded).isEmpty)
    }

    /// 一部が欠けていればその voice を検出する
    func test_missingVoices_someMissing_reportsThem() {
        var loaded = Set(KokoroVoice.allCases.map(\.rawValue))
        loaded.remove(KokoroVoice.jmKumo.rawValue)
        loaded.remove(KokoroVoice.bfEmma.rawValue)
        let missing = Set(KokoroAudioUtil.missingVoices(loadedKeys: loaded).map(\.rawValue))
        XCTAssertEqual(missing, ["jm_kumo", "bf_emma"])
    }

    /// 空のキー集合なら全 12 ボイスが欠損として返る
    func test_missingVoices_emptyKeys_reportsAll12() {
        let missing = KokoroAudioUtil.missingVoices(loadedKeys: [])
        XCTAssertEqual(missing.count, 12)
    }

    /// enum の raw value が Issue #88 記載の 12 キーと一致する（enum ドリフト検出）
    func test_kokoroVoice_allCases_matchExpected12Keys() {
        let expected: Set<String> = [
            "af_heart", "af_bella", "af_nicole", "af_sarah",
            "am_adam", "am_michael", "bf_emma", "bf_isabella",
            "bm_george", "bm_lewis", "jf_alpha", "jm_kumo",
        ]
        XCTAssertEqual(Set(KokoroVoice.allCases.map(\.rawValue)), expected)
        XCTAssertEqual(KokoroVoice.allCases.count, 12)
    }

    // MARK: - KokoroBundleResource (Issue #87: Bundle.main リソース名の固定)
    //
    // Bundle.module → Bundle.main への移行後、リソース名/localeマッピングがずれると
    // Bundle.main.url(forResource:) が nil を返し loadConfig() の try! がクラッシュ、
    // loadGold()/loadSilver() が空辞書を返す。名前をロックして退行を検出する。

    func test_bundleResource_config_isConfig() {
        XCTAssertEqual(KokoroBundleResource.config, "config")
    }

    func test_bundleResource_gold_matchesLocale() {
        XCTAssertEqual(KokoroBundleResource.gold(british: false), "us_gold")
        XCTAssertEqual(KokoroBundleResource.gold(british: true), "gb_gold")
    }

    func test_bundleResource_silver_matchesLocale() {
        XCTAssertEqual(KokoroBundleResource.silver(british: false), "us_silver")
        XCTAssertEqual(KokoroBundleResource.silver(british: true), "gb_silver")
    }

    func test_bundleResource_bartConfig_matchesLocale() {
        XCTAssertEqual(KokoroBundleResource.bartConfig(british: false), "us_bart_config")
        XCTAssertEqual(KokoroBundleResource.bartConfig(british: true), "gb_bart_config")
    }

    func test_bundleResource_bartWeights_matchesLocale() {
        XCTAssertEqual(KokoroBundleResource.bartWeights(british: false), "us_bart")
        XCTAssertEqual(KokoroBundleResource.bartWeights(british: true), "gb_bart")
    }

    // MARK: - MisakiLexicon.parse (loadGold/loadSilver の返り値契約)

    /// 正常なJSON辞書 → 空でない [grapheme: phoneme]（期待結果: 空辞書でなく正常データ）
    func test_misakiLexicon_validJSON_returnsNonEmpty() {
        let dict = MisakiLexicon.parse(Data(#"{"'cause":"kˈʌz","hello":"həˈloʊ"}"#.utf8))
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["'cause"] as? String, "kˈʌz")
    }

    /// data が nil（リソース欠落相当） → 空辞書にフォールバックしクラッシュしない
    func test_misakiLexicon_nilData_returnsEmpty() {
        XCTAssertTrue(MisakiLexicon.parse(nil).isEmpty)
    }

    /// 壊れたJSON → 空辞書にフォールバック
    func test_misakiLexicon_malformedJSON_returnsEmpty() {
        XCTAssertTrue(MisakiLexicon.parse(Data("not json".utf8)).isEmpty)
    }

    /// トップレベルが辞書でない（配列） → 空辞書にフォールバック
    func test_misakiLexicon_jsonArray_returnsEmpty() {
        XCTAssertTrue(MisakiLexicon.parse(Data("[1,2,3]".utf8)).isEmpty)
    }

    // MARK: - KokoroConfig.decodeConfig (loadConfig の try! が config.json 形状でクラッシュしない)

    /// バンドルされる config.json と同じ形状の JSON がクラッシュせずデコードできる
    func test_decodeConfig_validConfigShape_decodesWithoutThrowing() throws {
        let config = try KokoroConfig.decodeConfig(from: Self.configJSONFixture)
        XCTAssertEqual(config.dimIn, 64)
        XCTAssertEqual(config.nToken, 178)
        XCTAssertEqual(config.istftNet.upsampleInitialChannel, 512)
        XCTAssertEqual(config.plbert.hiddenSize, 768)
    }

    /// 必須フィールド欠落 → デコード失敗（try! なら fail-fast する挙動をドキュメント）
    func test_decodeConfig_missingFields_throws() {
        XCTAssertThrowsError(try KokoroConfig.decodeConfig(from: "{}"))
    }

    // MARK: - Helpers

    /// バンドルされる config.json（KokoroSwiftSources/config.json）と同じキー構造。
    /// vocab は decode 検証には不要なので空にしてある。
    private static let configJSONFixture = """
    {
      "istftnet": {
        "upsample_kernel_sizes": [20, 12],
        "upsample_rates": [10, 6],
        "gen_istft_hop_size": 5,
        "gen_istft_n_fft": 20,
        "resblock_dilation_sizes": [[1, 3, 5], [1, 3, 5], [1, 3, 5]],
        "resblock_kernel_sizes": [3, 7, 11],
        "upsample_initial_channel": 512
      },
      "dim_in": 64,
      "dropout": 0.2,
      "hidden_dim": 512,
      "max_conv_dim": 512,
      "max_dur": 50,
      "multispeaker": true,
      "n_layer": 3,
      "n_mels": 80,
      "n_token": 178,
      "style_dim": 128,
      "text_encoder_kernel_size": 5,
      "plbert": {
        "hidden_size": 768,
        "num_attention_heads": 12,
        "intermediate_size": 2048,
        "max_position_embeddings": 512,
        "num_hidden_layers": 12,
        "dropout": 0.1
      },
      "vocab": {}
    }
    """

    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base])
            | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16)
            | (UInt32(data[base + 3]) << 24)
    }

    private func readInt16LE(_ data: Data, at offset: Int) -> Int16 {
        let base = data.startIndex + offset
        let raw = UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
        return Int16(bitPattern: raw)
    }
}
