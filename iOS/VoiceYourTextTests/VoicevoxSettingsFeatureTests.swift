import ComposableArchitecture
import XCTest
@testable import VoiceYourText

@MainActor
final class VoicevoxSettingsFeatureTests: XCTestCase {
    private let freeUsage = VoicevoxUsage(plan: "free", used: 120, limit: 5000, remaining: 4880,
                                          resetAt: Date(timeIntervalSince1970: 1_790_780_400))
    private let exhausted = VoicevoxUsage(plan: "free", used: 5000, limit: 5000, remaining: 0,
                                          resetAt: Date(timeIntervalSince1970: 1_790_780_400))

    private func settings(enabled: Bool, speakerId: Int, saved: LockIsolated<[String]>) -> VoicevoxSettingsClient {
        VoicevoxSettingsClient(
            isEnabled: { enabled },
            setEnabled: { value in saved.withValue { $0.append("enabled=\(value)") } },
            speakerId: { speakerId },
            setSpeakerId: { value in saved.withValue { $0.append("speaker=\(value)") } }
        )
    }

    func testOnAppearLoadsSavedSettingsAndUsage() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: true, speakerId: 3, saved: saved)
            $0.voicevox.quota = { self.freeUsage }
        }
        await store.send(.view(.onAppear)) {
            $0.isEnabled = true
            $0.selectedSpeakerId = 3
        }
        await store.receive(\.usageLoaded) {
            $0.usage = self.freeUsage
        }
    }

    func testUsageFailureIsShownWithoutBreakingSettings() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: true, speakerId: 14, saved: saved)
            $0.voicevox.quota = { throw VoicevoxError.appCheckUnavailable }
        }
        await store.send(.view(.onAppear)) {
            $0.isEnabled = true
        }
        await store.receive(\.usageFailed) {
            $0.isUsageUnavailable = true
        }
    }

    func testOnAppearWhileOffDoesNotWakeServer() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: false, speakerId: 14, saved: saved)
            // quota は未実装のまま（呼ばれたらテストが落ちる）
        }
        await store.send(.view(.onAppear))
    }

    func testPickingVoiceWhileOffTurnsCharacterVoiceOn() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: false, speakerId: 14, saved: saved)
            $0.voicevox.quota = { self.freeUsage }
            $0.voicevoxPlayer.stop = {}
            $0.voicevoxPlayer.play = { _, _, _ in AsyncStream { $0.yield(.finished); $0.finish() } }
        }
        await store.send(.view(.voiceTapped(11))) {
            $0.isEnabled = true
            $0.selectedSpeakerId = 11
            $0.previewingSpeakerId = 11
        }
        await store.receive(\.previewFinished) {
            $0.previewingSpeakerId = nil
        }
        await store.receive(\.usageLoaded) {
            $0.usage = self.freeUsage
        }
        XCTAssertEqual(saved.value, ["enabled=true", "speaker=11"])
    }

    func testTurningOnSavesAndLogs() async {
        let saved = LockIsolated<[String]>([])
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State()) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: false, speakerId: 14, saved: saved)
            $0.voicevox.quota = { self.freeUsage }
            $0.analytics.logEvent = { name, _ in events.withValue { $0.append(name) } }
        }
        await store.send(.view(.enabledChanged(true))) {
            $0.isEnabled = true
        }
        await store.receive(\.usageLoaded) {
            $0.usage = self.freeUsage
        }
        XCTAssertEqual(saved.value, ["enabled=true"])
        XCTAssertEqual(events.value, ["voicevox_toggle"])
    }

    func testTappingVoiceSelectsSavesAndPreviews() async {
        let saved = LockIsolated<[String]>([])
        let played = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(isEnabled: true)) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: true, speakerId: 14, saved: saved)
            $0.voicevox.quota = { self.freeUsage }
            $0.voicevoxPlayer.stop = {}
            $0.voicevoxPlayer.play = { text, speakerId, _ in
                played.withValue { $0.append("\(speakerId):\(text)") }
                return AsyncStream { continuation in
                    continuation.yield(.sentence(NSRange(location: 0, length: 5)))
                    continuation.yield(.finished)
                    continuation.finish()
                }
            }
        }
        await store.send(.view(.voiceTapped(3))) {
            $0.selectedSpeakerId = 3
            $0.previewingSpeakerId = 3
        }
        await store.receive(\.previewFinished) {
            $0.previewingSpeakerId = nil
        }
        await store.receive(\.usageLoaded) {
            $0.usage = self.freeUsage
        }
        XCTAssertEqual(saved.value, ["speaker=3"])
        XCTAssertEqual(played.value, ["3:こんにちは、ずんだもんです。この声で読み上げます。"])
    }

    func testPreviewOverQuotaShowsPaywallForFreeUser() async {
        let saved = LockIsolated<[String]>([])
        let store = TestStore(initialState: VoicevoxSettingsFeature.State(isEnabled: true)) {
            VoicevoxSettingsFeature()
        } withDependencies: {
            $0.voicevoxSettings = settings(enabled: true, speakerId: 14, saved: saved)
            $0.voicevoxPlayer.stop = {}
            $0.voicevoxPlayer.play = { _, _, _ in
                AsyncStream { continuation in
                    continuation.yield(.quotaExceeded(self.exhausted, resumeAt: 0))
                    continuation.finish()
                }
            }
        }
        await store.send(.view(.voiceTapped(14))) {
            $0.previewingSpeakerId = 14
        }
        await store.receive(\.previewQuotaExceeded) {
            $0.previewingSpeakerId = nil
            $0.usage = self.exhausted
            $0.showPaywall = true
        }
    }

    func testCatalogMatchesServerAllowList() {
        // サーバー側 voicevox-server/internal/voices と同じ6声（規約を確認済みの声だけ）
        XCTAssertEqual(VoicevoxCatalog.voices.map(\.speakerId), [14, 3, 2, 11, 12, 9])
        XCTAssertTrue(VoicevoxCatalog.voices.allSatisfy { $0.credit.hasPrefix("VOICEVOX:") })
        XCTAssertFalse(VoicevoxCatalog.voices.contains { [30, 31, 13, 20, 10].contains($0.speakerId) },
                       "No.7・青山龍星・もち子さん・雨晴はうは要許可")
    }

    func testOnlyJapaneseUsesCharacterVoices() {
        XCTAssertTrue(VoicevoxCatalog.isAvailable(languageCode: "ja"))
        XCTAssertTrue(VoicevoxCatalog.isAvailable(languageCode: nil))
        XCTAssertFalse(VoicevoxCatalog.isAvailable(languageCode: "en"))
    }
}
