import Foundation
import Dependencies

/// サーバーから取得したキャラ一覧。配列順が表示順、既定の声もサーバーが決める。
struct VoicevoxCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let revision: String
    let defaultSpeakerId: Int?
    let termsUrl: String
    let voices: [VoicevoxVoice]
    let credits: [VoicevoxVoice]

    static let unselectedSpeakerId = -1

    func voice(for speakerId: Int) -> VoicevoxVoice? { voices.first { $0.speakerId == speakerId } }

    func selection(for savedId: Int) -> Int? {
        voice(for: savedId)?.speakerId ?? defaultSpeakerId
    }

    func validated() throws -> Self {
        guard schemaVersion == 1, !revision.isEmpty, Self.isHTTPS(termsUrl),
              Set(voices.map(\.speakerId)).count == voices.count,
              Set(credits.map(\.speakerId)).count == credits.count,
              (voices + credits).allSatisfy({ $0.speakerId >= 0 && !$0.character.isEmpty && !$0.style.isEmpty && !$0.credit.isEmpty && Self.isHTTPS($0.termsUrl) }),
              voices.allSatisfy({ voice in credits.contains { $0.speakerId == voice.speakerId } }) else {
            throw VoicevoxError.invalidResponse
        }
        if voices.isEmpty {
            guard defaultSpeakerId == nil else { throw VoicevoxError.invalidResponse }
        } else {
            guard let defaultSpeakerId, voice(for: defaultSpeakerId) != nil else { throw VoicevoxError.invalidResponse }
        }
        return self
    }

    static func isHTTPS(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return url.scheme == "https" && url.host?.isEmpty == false && url.user == nil
    }

    /// VOICEVOXエンジンは日本語向け。
    static func isAvailable(languageCode: String?) -> Bool { (languageCode ?? "ja").hasPrefix("ja") }
}

/// 最後に検証できた一覧をクレジット表示用にも保持する。生成時は必ず最新一覧を取得する。
enum VoicevoxCatalogCache {
    private static let key = "VoicevoxServerCatalog.v1"
    static func load() -> VoicevoxCatalog? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(VoicevoxCatalog.self, from: data).validated()
    }
    static func store(_ catalog: VoicevoxCatalog) throws {
        let data = try JSONEncoder().encode(catalog.validated())
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// キャラ音声の設定（UserDefaults）。
struct VoicevoxSettingsClient: Sendable {
    var isEnabled: @Sendable () -> Bool
    var setEnabled: @Sendable (Bool) -> Void
    var speakerId: @Sendable () -> Int
    var setSpeakerId: @Sendable (Int) -> Void
}

extension VoicevoxSettingsClient: DependencyKey {
    static let enabledKey = "VoicevoxEnabled"
    static let speakerIdKey = "VoicevoxSpeakerId"

    static let liveValue = Self(
        isEnabled: { UserDefaults.standard.bool(forKey: enabledKey) },
        setEnabled: { UserDefaults.standard.set($0, forKey: enabledKey) },
        speakerId: {
            // 新しいサーバーIDも保存できる。利用可否と既定の選択は取得した一覧で判定する。
            UserDefaults.standard.object(forKey: speakerIdKey) as? Int ?? VoicevoxCatalog.unselectedSpeakerId
        },
        setSpeakerId: { UserDefaults.standard.set($0, forKey: speakerIdKey) }
    )

    static let testValue = Self(
        isEnabled: unimplemented("VoicevoxSettingsClient.isEnabled", placeholder: false),
        setEnabled: unimplemented("VoicevoxSettingsClient.setEnabled"),
        speakerId: unimplemented("VoicevoxSettingsClient.speakerId", placeholder: VoicevoxCatalog.unselectedSpeakerId),
        setSpeakerId: unimplemented("VoicevoxSettingsClient.setSpeakerId")
    )
}

extension DependencyValues {
    var voicevoxSettings: VoicevoxSettingsClient {
        get { self[VoicevoxSettingsClient.self] }
        set { self[VoicevoxSettingsClient.self] = newValue }
    }
}
