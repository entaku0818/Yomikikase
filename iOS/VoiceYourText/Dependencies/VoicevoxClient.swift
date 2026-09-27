import Foundation
import Dependencies
import FirebaseAppCheck
import RevenueCat

/// キャラ音声（VOICEVOX）サーバーのクライアント。
///
/// サーバーは App Check で本物のアプリからの呼び出しかを確かめ、RevenueCat の App User ID で
/// プレミアム判定と月の文字数を数える（voicevox-server/README.md）。
struct VoicevoxClient {
    var voices: @Sendable () async throws -> [VoicevoxVoice]
    var quota: @Sendable () async throws -> VoicevoxUsage
    var synthesize: @Sendable (_ text: String, _ speakerId: Int, _ speedScale: Double) async throws -> VoicevoxAudio
}

struct VoicevoxVoice: Codable, Equatable, Identifiable, Sendable {
    let speakerId: Int
    let character: String
    let style: String
    let credit: String
    let termsUrl: String

    var id: Int { speakerId }
}

struct VoicevoxUsage: Codable, Equatable, Sendable {
    let plan: String
    let used: Int
    let limit: Int
    let remaining: Int
    let resetAt: Date

    var isPremium: Bool { plan == "premium" }
}

struct VoicevoxPhrase: Codable, Equatable, Sendable {
    let kana: String
    let start: Double
    let end: Double
}

struct VoicevoxAudio: Equatable, Sendable {
    /// m4a（AAC）
    let data: Data
    let format: String
    let duration: Double
    let phrases: [VoicevoxPhrase]
    let usage: VoicevoxUsage
}

enum VoicevoxError: Error, Equatable {
    /// 今月の上限に達した。無料ユーザーには Paywall を出す
    case quotaExceeded(VoicevoxUsage)
    /// App Check トークンを取れない（シミュレータでデバッグトークン未登録など）
    case appCheckUnavailable
    case server(status: Int, code: String)
    case invalidResponse
}

extension VoicevoxClient: DependencyKey {
    static let baseURL = URL(string: "https://voicevox-tts-990821915106.asia-northeast1.run.app")!

    static let liveValue: Self = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        @Sendable func authorizedRequest(_ path: String, method: String) async throws -> URLRequest {
            guard let token = try? await AppCheck.appCheck().token(forcingRefresh: false) else {
                throw VoicevoxError.appCheckUnavailable
            }
            var request = URLRequest(url: baseURL.appendingPathComponent(path))
            request.httpMethod = method
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")
            request.setValue(Purchases.shared.appUserID, forHTTPHeaderField: "X-User-ID")
            return request
        }

        @Sendable func send(_ request: URLRequest) async throws -> Data {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw VoicevoxError.invalidResponse
            }
            if http.statusCode == 429,
               let body = try? decoder.decode(QuotaExceededBody.self, from: data) {
                throw VoicevoxError.quotaExceeded(body.usage)
            }
            guard (200..<300).contains(http.statusCode) else {
                let code = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "unknown"
                throw VoicevoxError.server(status: http.statusCode, code: code)
            }
            return data
        }

        return Self(
            voices: {
                let data = try await send(URLRequest(url: baseURL.appendingPathComponent("v1/voices")))
                return try decoder.decode(VoicesBody.self, from: data).voices
            },
            quota: {
                let data = try await send(try await authorizedRequest("v1/quota", method: "GET"))
                return try decoder.decode(VoicevoxUsage.self, from: data)
            },
            synthesize: { text, speakerId, speedScale in
                var request = try await authorizedRequest("v1/synthesize", method: "POST")
                request.httpBody = try JSONEncoder().encode(SynthesizeBody(text: text, speakerId: speakerId, speedScale: speedScale))
                let data = try await send(request)
                let body = try decoder.decode(SynthesizeResponse.self, from: data)
                guard let audio = Data(base64Encoded: body.audio) else {
                    throw VoicevoxError.invalidResponse
                }
                return VoicevoxAudio(data: audio, format: body.format, duration: body.duration, phrases: body.phrases, usage: body.usage)
            }
        )
    }()

    static let testValue = Self(
        voices: unimplemented("VoicevoxClient.voices", placeholder: []),
        quota: unimplemented("VoicevoxClient.quota", placeholder: VoicevoxUsage(plan: "free", used: 0, limit: 5000, remaining: 5000, resetAt: .distantFuture)),
        synthesize: unimplemented("VoicevoxClient.synthesize", placeholder: VoicevoxAudio(
            data: Data(), format: "m4a", duration: 0, phrases: [],
            usage: VoicevoxUsage(plan: "free", used: 0, limit: 5000, remaining: 5000, resetAt: .distantFuture)
        ))
    )
}

private struct VoicesBody: Decodable { let voices: [VoicevoxVoice] }
private struct ErrorBody: Decodable { let error: String }
private struct QuotaExceededBody: Decodable { let usage: VoicevoxUsage }
private struct SynthesizeBody: Encodable {
    let text: String
    let speakerId: Int
    let speedScale: Double
}
private struct SynthesizeResponse: Decodable {
    let audio: String
    let format: String
    let duration: Double
    let phrases: [VoicevoxPhrase]
    let usage: VoicevoxUsage
}

extension DependencyValues {
    var voicevox: VoicevoxClient {
        get { self[VoicevoxClient.self] }
        set { self[VoicevoxClient.self] = newValue }
    }
}
