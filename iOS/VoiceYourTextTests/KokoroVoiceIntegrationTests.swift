import XCTest
import ComposableArchitecture
@testable import VoiceYourText

final class KokoroVoiceIntegrationTests: XCTestCase {
    func testParticleReadingKeepsWordsAndQuotedLettersIntact() {
        XCTAssertEqual(JapaneseG2PProcessor.contextualReading(surface: "は", reading: "は", previous: "猫"), "わ")
        XCTAssertEqual(JapaneseG2PProcessor.contextualReading(surface: "は", reading: "は", previous: "「"), "は")
        XCTAssertEqual(JapaneseG2PProcessor.contextualReading(surface: "は", reading: "は", previous: nil), "は")
        XCTAssertEqual(JapaneseG2PProcessor.contextualReading(surface: "母", reading: "はは", previous: nil), "はは")
        XCTAssertEqual(JapaneseG2PProcessor.contextualReading(surface: "ははは", reading: "ははは", previous: nil), "ははは")
        XCTAssertEqual(JapaneseG2PProcessor.contextualReading(surface: "こんにちは", reading: "こんにちは", previous: nil), "こんにちわ")
    }

    func testEveryJapaneseVoiceIsUsedForJapaneseText() {
        let voices: [KokoroVoice] = [.jfAlpha, .jfGongitsune, .jfTebukuro, .jfNezumi, .jmKumo]
        for voice in voices {
            XCTAssertEqual(KokoroPlaybackParams.selectVoice(languageCode: "ja-JP", storedVoiceRaw: voice.rawValue), voice)
        }
    }

    func testUnsupportedLanguageUsesDeviceVoice() {
        XCTAssertFalse(KokoroPlaybackParams.shouldUseKokoro(available: true, enabled: true, languageCode: "fr"))
    }

    func testTopicParticleInActualText() throws {
        let phonemes = try JapaneseG2PProcessor().process(input: "私は本を読みます。").0
        XCTAssertTrue(phonemes.contains("wa"), phonemes)
        XCTAssertFalse(phonemes.contains("ɕiha"), phonemes)
    }

    func testWrongLanguageVoiceFallsBack() {
        XCTAssertEqual(KokoroPlaybackParams.selectVoice(languageCode: "ja", storedVoiceRaw: "af_heart"), .jfAlpha)
        XCTAssertEqual(KokoroPlaybackParams.selectVoice(languageCode: "en", storedVoiceRaw: "jf_alpha"), .afHeart)
    }

    func testGeneratedAudioDoesNotApplySpeedTwice() {
        for rate: Float in [0.25, 0.5, 0.75, 1] {
            XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: rate, synthesisApplied: true), 1)
            XCTAssertEqual(KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: rate), rate * 2)
        }
    }

    @MainActor
    func testStoppingPreviewCancelsSynthesis() async {
        let preview = KokoroVoicePreview { _, _, _ in
            try await Task.sleep(for: .seconds(60))
            return Data()
        }
        preview.toggle(.jfAlpha)
        let task = preview.task
        XCTAssertEqual(preview.voice, .jfAlpha)
        preview.stop()
        await task?.value
        XCTAssertNil(preview.voice)
        XCTAssertFalse(preview.isGenerating)
        XCTAssertNil(preview.errorMessage)
    }

    @MainActor
    func testFailedPreviewCanBeRetried() async {
        let preview = KokoroVoicePreview { _, _, _ in throw KokoroError.modelNotDownloaded }
        preview.toggle(.jmKumo)
        await preview.task?.value
        XCTAssertNil(preview.voice)
        XCTAssertNotNil(preview.errorMessage)
        preview.toggle(.jfTebukuro)
        XCTAssertEqual(preview.voice, .jfTebukuro)
        XCTAssertNil(preview.errorMessage)
        preview.stop()
    }

    @MainActor
    func testSelectingEachVoiceEnablesKokoro() async {
        for voice in KokoroVoice.allCases where voice.isJapanese {
            let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
                $0.userDefaults.languageSetting = { "ja" }
                $0.userDefaults.setKokoroVoice = { _ in }
                $0.userDefaults.setKokoroEnabled = { _ in }
                $0.voicevoxSettings.setEnabled = { _ in }
            }
            await store.send(.view(.setKokoroVoice(voice.rawValue))) {
                $0.kokoroVoice = voice.rawValue
                $0.kokoroEnabled = true
            }
        }
    }
}
