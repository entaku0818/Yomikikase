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
    var getCacheSize: @Sendable () -> Int64
    var clearCache: @Sendable () throws -> Int
    var cleanupOldFiles: @Sendable (Int64) throws -> Int  // maxSize in bytes
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

                // Determine file extension from URL path (ignoring query parameters)
                // For signed URLs like "https://storage.googleapis.com/.../file.wav?X-Goog-..."
                var urlComponents = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false)
                urlComponents?.query = nil  // Remove query parameters
                let cleanPath = urlComponents?.path ?? remoteURL.path
                let pathExtension = (cleanPath as NSString).pathExtension
                let fileExtension = pathExtension.isEmpty ? "wav" : pathExtension

                infoLog("AudioFileManager: Downloading audio for \(identifier), extension: \(fileExtension)")

                let localFileName = "\(identifier).\(fileExtension)"
                let localURL = audioDirectory.appendingPathComponent(localFileName)

                // Remove existing file if any
                if fileManager.fileExists(atPath: localURL.path) {
                    try? fileManager.removeItem(at: localURL)
                }

                // Move downloaded file to permanent location
                try fileManager.moveItem(at: tempURL, to: localURL)

                infoLog("AudioFileManager: Saved audio to \(localURL.path)")
                return localURL
            },
            getLocalAudioPath: { identifier in
                // Look for audio file with any common extension
                let extensions = ["wav", "mp3", "m4a", "aac"]
                infoLog("AudioFileManager: Looking for audio file with identifier: \(identifier)")
                for ext in extensions {
                    let localURL = audioDirectory.appendingPathComponent("\(identifier).\(ext)")
                    if fileManager.fileExists(atPath: localURL.path) {
                        infoLog("AudioFileManager: Found audio file at \(localURL.path)")
                        return localURL
                    }
                }
                infoLog("AudioFileManager: No audio file found for \(identifier) in \(audioDirectory.path)")
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
            },
            getCacheSize: {
                var totalSize: Int64 = 0
                if let files = try? fileManager.contentsOfDirectory(atPath: audioDirectory.path) {
                    for file in files {
                        let filePath = audioDirectory.appendingPathComponent(file).path
                        if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                           let fileSize = attributes[.size] as? Int64 {
                            totalSize += fileSize
                        }
                    }
                }
                return totalSize
            },
            clearCache: {
                var deletedCount = 0
                if let files = try? fileManager.contentsOfDirectory(atPath: audioDirectory.path) {
                    for file in files {
                        let filePath = audioDirectory.appendingPathComponent(file)
                        try? fileManager.removeItem(at: filePath)
                        deletedCount += 1
                    }
                }
                infoLog("AudioFileManager: Cleared \(deletedCount) cached files")
                return deletedCount
            },
            cleanupOldFiles: { maxSize in
                // Get all files with their modification dates
                guard let files = try? fileManager.contentsOfDirectory(atPath: audioDirectory.path) else {
                    return 0
                }

                struct FileInfo {
                    let url: URL
                    let size: Int64
                    let modificationDate: Date
                }

                var fileInfos: [FileInfo] = []
                var totalSize: Int64 = 0

                for file in files {
                    let fileURL = audioDirectory.appendingPathComponent(file)
                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64,
                       let modDate = attributes[.modificationDate] as? Date {
                        fileInfos.append(FileInfo(url: fileURL, size: fileSize, modificationDate: modDate))
                        totalSize += fileSize
                    }
                }

                // If under limit, no cleanup needed
                if totalSize <= maxSize {
                    return 0
                }

                // Sort by modification date (oldest first)
                fileInfos.sort { $0.modificationDate < $1.modificationDate }

                var deletedCount = 0
                var currentSize = totalSize

                // Delete oldest files until under limit
                for fileInfo in fileInfos {
                    if currentSize <= maxSize {
                        break
                    }
                    try? fileManager.removeItem(at: fileInfo.url)
                    currentSize -= fileInfo.size
                    deletedCount += 1
                }

                infoLog("AudioFileManager: Cleaned up \(deletedCount) old files, freed \(totalSize - currentSize) bytes")
                return deletedCount
            }
        )
    }

    static let testValue = Self(
        downloadAudio: { _, identifier in
            URL(fileURLWithPath: "/tmp/test_\(identifier).wav")
        },
        getLocalAudioPath: { _ in nil },
        deleteAudio: { _ in },
        audioExists: { _ in false },
        getCacheSize: { 0 },
        clearCache: { 0 },
        cleanupOldFiles: { _ in 0 }
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
