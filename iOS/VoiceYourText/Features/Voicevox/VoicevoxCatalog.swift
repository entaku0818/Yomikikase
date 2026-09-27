import Foundation
import Dependencies

/// アプリで選べるキャラ音声。サーバーの許可リスト（voicevox-server/internal/voices）と同じ内容にする。
///
/// 有料アプリで申請なしに使えることを各キャラの利用規約で確認した声だけを載せている（2026-09-27）。
/// 声を足すときは、キャラの規約とクレジット書式を確認し、サーバー側の許可リストにも追加すること。
enum VoicevoxCatalog {
    static let voices: [VoicevoxVoice] = [
        VoicevoxVoice(speakerId: 14, character: "冥鳴ひまり", style: "ノーマル", credit: "VOICEVOX:冥鳴ひまり",
                      termsUrl: "https://meimeihimari.wixsite.com/himari/terms-of-use"),
        VoicevoxVoice(speakerId: 3, character: "ずんだもん", style: "ノーマル", credit: "VOICEVOX:ずんだもん",
                      termsUrl: "https://zunko.jp/con_ongen_kiyaku.html"),
        VoicevoxVoice(speakerId: 2, character: "四国めたん", style: "ノーマル", credit: "VOICEVOX:四国めたん",
                      termsUrl: "https://zunko.jp/con_ongen_kiyaku.html"),
        VoicevoxVoice(speakerId: 11, character: "玄野武宏", style: "ノーマル", credit: "VOICEVOX:玄野武宏(CV:ガロ)",
                      termsUrl: "https://www.virvoxproject.com/voicevoxの利用規約"),
        VoicevoxVoice(speakerId: 12, character: "白上虎太郎", style: "ふつう", credit: "VOICEVOX:白上虎太郎(CV:可愛ユウ)",
                      termsUrl: "https://www.virvoxproject.com/voicevoxの利用規約"),
        VoicevoxVoice(speakerId: 9, character: "波音リツ", style: "ノーマル", credit: "VOICEVOX:波音リツ",
                      termsUrl: "https://www.canon-voice.com/terms"),
    ]

    static let defaultSpeakerId = 14

    static func voice(for speakerId: Int) -> VoicevoxVoice {
        voices.first { $0.speakerId == speakerId } ?? voices[0]
    }

    /// キャラ音声は日本語の文章だけに使う
    static func isAvailable(languageCode: String?) -> Bool {
        (languageCode ?? "ja").hasPrefix("ja")
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
            let stored = UserDefaults.standard.integer(forKey: speakerIdKey)
            // 許可リストから外れた声が保存されていたら既定に戻す
            return VoicevoxCatalog.voices.contains { $0.speakerId == stored } ? stored : VoicevoxCatalog.defaultSpeakerId
        },
        setSpeakerId: { UserDefaults.standard.set($0, forKey: speakerIdKey) }
    )

    static let testValue = Self(
        isEnabled: unimplemented("VoicevoxSettingsClient.isEnabled", placeholder: false),
        setEnabled: unimplemented("VoicevoxSettingsClient.setEnabled"),
        speakerId: unimplemented("VoicevoxSettingsClient.speakerId", placeholder: VoicevoxCatalog.defaultSpeakerId),
        setSpeakerId: unimplemented("VoicevoxSettingsClient.setSpeakerId")
    )
}

extension DependencyValues {
    var voicevoxSettings: VoicevoxSettingsClient {
        get { self[VoicevoxSettingsClient.self] }
        set { self[VoicevoxSettingsClient.self] = newValue }
    }
}
