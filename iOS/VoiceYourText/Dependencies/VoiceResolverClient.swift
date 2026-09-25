import Foundation
import ComposableArchitecture
import AVFoundation

/// reducer から `VoiceResolver.configure` を呼ぶためのクライアント。
///
/// `AVSpeechSynthesisVoice(language:)` はシミュレータで音声サービスの応答待ちのまま
/// 戻らないことがあり、reducer のテスト（TestStore）がハングする原因になる。
/// テストでは音声の解決をせず、速度・ピッチ・音量だけ設定する。
struct VoiceResolverClient {
    var configure: @Sendable (_ utterance: AVSpeechUtterance, _ languageCode: String?, _ rate: Float, _ pitch: Float) -> Void
}

extension VoiceResolverClient: DependencyKey {
    static let liveValue = Self(
        configure: { utterance, languageCode, rate, pitch in
            VoiceResolver.configure(utterance, languageCode: languageCode, rate: rate, pitch: pitch)
        }
    )

    static let testValue = Self(
        configure: { utterance, _, rate, pitch in
            VoiceResolver.applyParameters(utterance, rate: rate, pitch: pitch)
        }
    )
}

extension DependencyValues {
    var voiceResolver: VoiceResolverClient {
        get { self[VoiceResolverClient.self] }
        set { self[VoiceResolverClient.self] = newValue }
    }
}
