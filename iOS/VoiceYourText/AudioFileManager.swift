//
//  AudioFileManager.swift
//  VoiceYourText
//
//  Created by Claude Code on 2025/01/08.
//

import Foundation
import ComposableArchitecture

struct AudioFileManager {
    var downloadAudio: @Sendable (URL, String) async throws -> URL
    var getLocalAudioPath: @Sendable (String) -> URL?
    var deleteAudio: @Sendable (String) throws -> Void
    var audioExists: @Sendable (String) -> Bool
}

extension AudioFileManager: DependencyKey {
    static var liveValue: Self {
        let fileManager = FileManager.default

        // Get audio directory in Documents
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsURL.appendingPathComponent("audio", isDirectory: true)

        // Create audio directory if needed
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        return Self(
            downloadAudio: { remoteURL, identifier in
                // Download audio file from remote URL
                let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw AudioFileError.downloadFailed
                }

                // Determine file extension from URL or response
                let fileExtension = remoteURL.pathExtension.isEmpty ? "wav" : remoteURL.pathExtension
                let localFileName = "\(identifier).\(fileExtension)"
                let localURL = audioDirectory.appendingPathComponent(localFileName)

                // Remove existing file if any
                if fileManager.fileExists(atPath: localURL.path) {
                    try? fileManager.removeItem(at: localURL)
                }

                // Move downloaded file to permanent location
                try fileManager.moveItem(at: tempURL, to: localURL)

                return localURL
            },
            getLocalAudioPath: { identifier in
                // Look for audio file with any common extension
                let extensions = ["wav", "mp3", "m4a", "aac"]
                for ext in extensions {
                    let localURL = audioDirectory.appendingPathComponent("\(identifier).\(ext)")
                    if fileManager.fileExists(atPath: localURL.path) {
                        return localURL
                    }
                }
                return nil
            },
            deleteAudio: { identifier in
                let extensions = ["wav", "mp3", "m4a", "aac"]
                for ext in extensions {
                    let localURL = audioDirectory.appendingPathComponent("\(identifier).\(ext)")
                    if fileManager.fileExists(atPath: localURL.path) {
                        try fileManager.removeItem(at: localURL)
                    }
                }
            },
            audioExists: { identifier in
                let extensions = ["wav", "mp3", "m4a", "aac"]
                for ext in extensions {
                    let localURL = audioDirectory.appendingPathComponent("\(identifier).\(ext)")
                    if fileManager.fileExists(atPath: localURL.path) {
                        return true
                    }
                }
                return false
            }
        )
    }

    static let testValue = Self(
        downloadAudio: { _, identifier in
            URL(fileURLWithPath: "/tmp/test_\(identifier).wav")
        },
        getLocalAudioPath: { _ in nil },
        deleteAudio: { _ in },
        audioExists: { _ in false }
    )
}

extension DependencyValues {
    var audioFileManager: AudioFileManager {
        get { self[AudioFileManager.self] }
        set { self[AudioFileManager.self] = newValue }
    }
}

enum AudioFileError: Error, LocalizedError {
    case downloadFailed
    case fileNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download audio file"
        case .fileNotFound:
            return "Audio file not found"
        case .saveFailed:
            return "Failed to save audio file"
        }
    }
}
