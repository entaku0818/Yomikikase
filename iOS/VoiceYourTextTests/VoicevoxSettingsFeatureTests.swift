import ComposableArchitecture
import XCTest
@testable import VoiceYourText

@MainActor
final class VoicevoxSettingsFeatureTests: XCTestCase {
    private let freeUsage = VoicevoxUsage(plan: "free", used: 120, limit: 5000, remaining: 4880, resetAt: .distantFuture)
    private let exhausted = VoicevoxUsage(plan: "free", used: 5000, limit: 5000, remaining: 0, resetAt: .distantFuture)

    nonisolated private var catalog: VoicevoxCatalog {
        let voices = [voice(14, "既定"), voice(3, "ずんだもん"), voice(11, "テスト")]
        return VoicevoxCatalog(schemaVersion: 1, revision: "test.1", defaultSpeakerId: 14,
                               termsUrl: "https://example.com/terms", voices: voices, credits: voices)
    }
    nonisolated private func voice(_ id: Int, _ name: String) -> VoicevoxVoice {
        VoicevoxVoice(speakerId: id, character: name, style: "ノーマル", credit: "VOICEVOX:\(name)", termsUrl: "https://example.com/voice")
    }
    private func settings(enabled: Bool, speakerId: Int, saved: LockIsolated<[String]>) -> VoicevoxSettingsClient {
        VoicevoxSettingsClient(isEnabled: { enabled }, setEnabled: { value in saved.withValue { $0.append("enabled=\(value)") } },
            speakerId: { speakerId }, setSpeakerId: { value in saved.withValue { $0.append("speaker=\(value)") } })
    }

    func testOnAppearLoadsServerCatalogAndUsage() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings = settings(enabled: true, speakerId: 3, saved: saved)
            $0.voicevox.catalog = { self.catalog }
            $0.voicevox.quota = { self.freeUsage }
        }
        await store.send(.view(.onAppear)) { $0.isEnabled = true; $0.selectedSpeakerId = 3; $0.isCatalogLoading = true }
        await store.receive(\.catalogLoaded) { $0.catalog = self.catalog; $0.isCatalogLoading = false }
        await store.receive(\.usageLoaded) { $0.usage = self.freeUsage }
        XCTAssertEqual(saved.value, [])
    }

    func testFailedCatalogDoesNotRestoreHardcodedChoices() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings = settings(enabled: true, speakerId: 14, saved: saved)
            $0.voicevox.cachedCatalog = { self.catalog }
            $0.voicevox.catalog = { throw VoicevoxError.invalidResponse }
            $0.voicevox.quota = { throw VoicevoxError.appCheckUnavailable }
        }
        await store.send(.view(.onAppear)) {
            $0.isEnabled = true; $0.selectedSpeakerId = 14; $0.catalog = self.catalog; $0.isCatalogLoading = true
        }
        await store.receive(\.catalogFailed) { $0.catalog = nil; $0.isCatalogLoading = false; $0.isCatalogUnavailable = true }
        await store.receive(\.usageFailed) { $0.isUsageUnavailable = true }
        await store.send(.view(.voiceTapped(14)))
        XCTAssertTrue(store.state.voices.isEmpty)
    }

    func testOnAppearWhileOffDoesNotWakeServer() async {
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings = settings(enabled: false, speakerId: 401, saved: LockIsolated([]))
        }
        await store.send(.view(.onAppear)) { $0.selectedSpeakerId = 401 }
    }

    func testOpeningPickerWhileOffLoadsNewCharactersAndServerDefault() async {
        let saved = LockIsolated<[String]>([])
        let remote = VoicevoxCatalog(schemaVersion: 1, revision: "new", defaultSpeakerId: 401, termsUrl: "https://example.com/terms",
                                    voices: [voice(401, "追加キャラ")], credits: [voice(401, "追加キャラ")])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings.setSpeakerId = { id in saved.withValue { $0.append("\(id)") } }
            $0.voicevox.catalog = { remote }
        }
        await store.send(.view(.loadCatalog)) { $0.isCatalogLoading = true }
        await store.receive(\.catalogLoaded) { $0.catalog = remote; $0.isCatalogLoading = false; $0.selectedSpeakerId = 401 }
        XCTAssertEqual(saved.value, ["401"])
        XCTAssertEqual(store.state.voices.first?.character, "追加キャラ")
    }

    func testRetiredSelectionMovesToServerDefaultAndEmptyCatalogHasNoSelection() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(selectedSpeakerId: 999)) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings.setSpeakerId = { id in saved.withValue { $0.append("\(id)") } }
        }
        await store.send(.catalogLoaded(catalog)) { $0.catalog = self.catalog; $0.selectedSpeakerId = 14 }
        let empty = VoicevoxCatalog(schemaVersion: 1, revision: "disabled", defaultSpeakerId: nil,
                                   termsUrl: catalog.termsUrl, voices: [], credits: catalog.credits)
        await store.send(.catalogLoaded(empty)) { $0.catalog = empty; $0.selectedSpeakerId = -1 }
        XCTAssertEqual(saved.value, ["14", "-1"])
        XCTAssertNoThrow(try empty.validated())
        XCTAssertNil(empty.selection(for: 14))
    }

    func testPickingVoiceWhileOffTurnsOnAndPreviewsServerName() async {
        let saved = LockIsolated<[String]>([])
        let played = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(catalog: catalog)) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings = settings(enabled: false, speakerId: 14, saved: saved)
            $0.voicevox.quota = { self.freeUsage }
            $0.voicevoxPlayer.stop = {}
            $0.voicevoxPlayer.play = { text, id, _ in
                played.withValue { $0.append("\(id):\(text)") }
                return AsyncStream { $0.yield(.finished); $0.finish() }
            }
        }
        await store.send(.view(.voiceTapped(3))) { $0.isEnabled = true; $0.selectedSpeakerId = 3; $0.previewingSpeakerId = 3 }
        await store.receive(\.previewFinished) { $0.previewingSpeakerId = nil }
        await store.receive(\.usageLoaded) { $0.usage = self.freeUsage }
        XCTAssertEqual(saved.value, ["enabled=true", "speaker=3"])
        XCTAssertEqual(played.value, ["3:こんにちは、ずんだもんです。この声で読み上げます。"])
    }

    func testUnknownVoiceCannotStartPreviewOrConsumeQuota() async {
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(catalog: catalog)) { VoicevoxSettingsFeature() }
        await store.send(.view(.voiceTapped(401)))
    }

    func testTurningOnLoadsCatalogAndLogs() async {
        let saved = LockIsolated<[String]>([])
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(selectedSpeakerId: 14)) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings = settings(enabled: false, speakerId: 14, saved: saved)
            $0.voicevox.catalog = { self.catalog }
            $0.voicevox.quota = { self.freeUsage }
            $0.analytics.logEvent = { name, _ in events.withValue { $0.append(name) } }
        }
        await store.send(.view(.enabledChanged(true))) { $0.isEnabled = true; $0.isCatalogLoading = true }
        await store.receive(\.catalogLoaded) { $0.catalog = self.catalog; $0.isCatalogLoading = false }
        await store.receive(\.usageLoaded) { $0.usage = self.freeUsage }
        XCTAssertEqual(saved.value, ["enabled=true"])
        XCTAssertEqual(events.value, ["voicevox_toggle"])
    }

    func testPreviewOverQuotaShowsPaywallForFreeUser() async {
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(isEnabled: true, selectedSpeakerId: 14, catalog: catalog)) { VoicevoxSettingsFeature() } withDependencies: {
            $0.voicevoxSettings.setSpeakerId = { _ in }
            $0.voicevoxPlayer.stop = {}
            $0.voicevoxPlayer.play = { _, _, _ in AsyncStream { $0.yield(.quotaExceeded(self.exhausted, resumeAt: 0)); $0.finish() } }
        }
        await store.send(.view(.voiceTapped(14))) { $0.previewingSpeakerId = 14 }
        await store.receive(\.previewQuotaExceeded) { $0.previewingSpeakerId = nil; $0.usage = self.exhausted; $0.showPaywall = true }
    }

    func testCatalogRejectsUnsafeLinksAndMissingDefaultAndKeepsCreditsInCacheEncoding() throws {
        var data = try JSONEncoder().encode(catalog)
        XCTAssertEqual(try JSONDecoder().decode(VoicevoxCatalog.self, from: data).validated(), catalog)
        let unsafe = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "https:", with: "javascript:")
        data = Data(unsafe.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(VoicevoxCatalog.self, from: data).validated())
        let missing = VoicevoxCatalog(schemaVersion: 1, revision: "r", defaultSpeakerId: 999, termsUrl: catalog.termsUrl, voices: catalog.voices, credits: catalog.credits)
        XCTAssertThrowsError(try missing.validated())
    }

    func testOnlyJapaneseUsesCharacterVoices() {
        XCTAssertTrue(VoicevoxCatalog.isAvailable(languageCode: "ja"))
        XCTAssertTrue(VoicevoxCatalog.isAvailable(languageCode: nil))
        XCTAssertFalse(VoicevoxCatalog.isAvailable(languageCode: "en"))
    }
}
