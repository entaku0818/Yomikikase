//
//  AudioAPIClient.swift
//  VoiceYourText
//
//  Created by Claude Code on 2025/01/17.
//

import Foundation
import Dependencies
import AVFoundation
import ComposableArchitecture


@DependencyClient
struct AudioAPIClient {
    var generateAudio: @Sendable (String, String?) async throws -> AudioResponse
    var getVoices: @Sendable (String?) async throws -> VoicesResponse
}

struct AudioResponse: Codable, Equatable {
    let success: Bool
    let originalText: String
    let language: String
    let voice: VoiceConfig
    let style: String
    let audioUrl: String
    let filename: String
    let mimeType: String
    let message: String
}

struct VoicesResponse: Codable, Equatable {
    let success: Bool
    let voices: [VoiceConfig]
}

struct VoiceConfig: Codable, Equatable {
    let id: String
    let name: String
    let language: String
    let gender: String
    let description: String
}

extension AudioAPIClient: DependencyKey {
    static var liveValue: Self {
        Self(
            generateAudio: { text, voiceId in
                guard let baseURL = Bundle.main.infoDictionary?["AUDIO_API_BASE_URL"] as? String,
                      !baseURL.isEmpty else {
                    throw AudioAPIError.notConfigured
                }

                guard let url = URL(string: "\(baseURL)/generateAudioWithTTS") else {
                    throw AudioAPIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // Add API key from config
                if let apiKey = Bundle.main.infoDictionary?["CLOUDRUN_API_KEY"] as? String,
                   !apiKey.isEmpty {
                    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
                }

                // Determine language from voiceId or default to ja-JP
                let language = voiceId?.hasPrefix("en-") == true ? "en-US" : "ja-JP"

                let body: [String: Any] = [
                    "text": text,
                    "voiceId": voiceId ?? "ja-jp-female-a",
                    "language": language,
                    "style": "cheerfully"
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AudioAPIError.networkError
                }

                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 401 {
                        throw AudioAPIError.unauthorized
                    }
                    throw AudioAPIError.serverError(httpResponse.statusCode)
                }

                do {
                    return try JSONDecoder().decode(AudioResponse.self, from: data)
                } catch {
                    throw AudioAPIError.decodingError
                }
            },
            getVoices: { language in
                guard let baseURL = Bundle.main.infoDictionary?["AUDIO_API_BASE_URL"] as? String,
                      !baseURL.isEmpty else {
                    throw AudioAPIError.notConfigured
                }

                var urlString = "\(baseURL)/getVoices"
                if let language = language {
                    urlString += "?language=\(language)"
                }

                guard let url = URL(string: urlString) else {
                    throw AudioAPIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw AudioAPIError.networkError
                }

                do {
                    return try JSONDecoder().decode(VoicesResponse.self, from: data)
                } catch {
                    throw AudioAPIError.decodingError
                }
            }
        )
    }
}

extension AudioAPIClient: TestDependencyKey {
    static let testValue = Self(
        generateAudio: { _, _ in
            AudioResponse(
                success: true,
                originalText: "テスト",
                language: "ja-JP",
                voice: VoiceConfig(id: "ja-jp-female-a", name: "あかり", language: "ja-JP", gender: "female", description: "明るく優しい女性の声"),
                style: "cheerfully",
                audioUrl: "https://example.com/test.wav",
                filename: "test.wav",
                mimeType: "audio/wav",
                message: "Test response"
            )
        },
        getVoices: { _ in
            VoicesResponse(
                success: true,
                voices: [
                    VoiceConfig(id: "ja-jp-female-a", name: "あかり", language: "ja-JP", gender: "female", description: "明るく優しい女性の声")
                ]
            )
        }
    )
}

extension DependencyValues {
    var audioAPI: AudioAPIClient {
        get { self[AudioAPIClient.self] }
        set { self[AudioAPIClient.self] = newValue }
    }
}

enum AudioAPIError: Error, LocalizedError {
    case networkError
    case decodingError
    case invalidURL
    case notConfigured
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .invalidURL:
            return "Invalid URL"
        case .notConfigured:
            return "API is not configured"
        case .unauthorized:
            return "Unauthorized - invalid API key"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
