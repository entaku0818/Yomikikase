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
                guard let baseUrl = Bundle.main.object(forInfoDictionaryKey: "AUDIO_API_BASE_URL") as? String,
                      !baseUrl.isEmpty else {
                    fatalError("AUDIO_API_BASE_URL is not configured. Please set AUDIO_API_BASE_URL in your .xcconfig file.")
                }
                let url = URL(string: "\(baseUrl)/generateAudioWithTTS")!
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "text": text,
                    "voiceId": voiceId ?? "ja-jp-female-a"
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw AudioAPIError.networkError
                }
                
                return try JSONDecoder().decode(AudioResponse.self, from: data)
            },
            getVoices: { language in
                guard let baseUrl = Bundle.main.object(forInfoDictionaryKey: "AUDIO_API_BASE_URL") as? String,
                      !baseUrl.isEmpty else {
                    fatalError("AUDIO_API_BASE_URL is not configured. Please set AUDIO_API_BASE_URL in your .xcconfig file.")
                }
                var urlComponents = URLComponents(string: "\(baseUrl)/getVoices")!
                if let language = language {
                    urlComponents.queryItems = [URLQueryItem(name: "language", value: language)]
                }
                
                let url = urlComponents.url!
                let (data, _) = try await URLSession.shared.data(from: url)
                
                return try JSONDecoder().decode(VoicesResponse.self, from: data)
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

enum AudioAPIError: Error {
    case networkError
    case decodingError
    case invalidURL
}
