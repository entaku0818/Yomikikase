//
//  WAVProcessor.swift
//  VoiceYourText
//

import Foundation

enum WAVProcessor {

    // MARK: - Duration

    /// WAV ファイルのヘッダーから再生時間（秒）を算出する
    static func duration(at url: URL) -> Double {
        guard let data = try? Data(contentsOf: url), data.count >= 44 else { return 0 }
        let sampleRate    = data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) }
        let dataSize      = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }
        let bitsPerSample = data.withUnsafeBytes { $0.load(fromByteOffset: 34, as: UInt16.self) }
        let numChannels   = data.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) }
        guard sampleRate > 0, bitsPerSample > 0, numChannels > 0 else { return 0 }
        let bytesPerSample = Int(bitsPerSample / 8) * Int(numChannels)
        guard bytesPerSample > 0 else { return 0 }
        return Double(Int(dataSize) / bytesPerSample) / Double(sampleRate)
    }

    // MARK: - Concatenation

    /// 複数の WAV ファイルを 1 つに結合する
    /// - 先頭ファイルのヘッダー（44 バイト）を流用し PCM データを連結する
    /// - 結合後に RIFF / data チャンクサイズを正しく更新する
    static func concatenate(_ urls: [URL], to outputURL: URL) throws {
        guard !urls.isEmpty else { return }
        guard let firstData = try? Data(contentsOf: urls[0]), firstData.count >= 44 else {
            throw WAVError.invalidHeader
        }

        var pcmData = Data()
        for url in urls {
            guard let d = try? Data(contentsOf: url), d.count > 44 else { continue }
            pcmData.append(d.dropFirst(44))
        }

        var result = Data(firstData.prefix(44))
        var riffSize = UInt32(36 + pcmData.count).littleEndian
        var dataSize = UInt32(pcmData.count).littleEndian
        withUnsafeBytes(of: &riffSize) { result.replaceSubrange(4..<8, with: $0) }
        withUnsafeBytes(of: &dataSize) { result.replaceSubrange(40..<44, with: $0) }
        result.append(pcmData)

        try? FileManager.default.removeItem(at: outputURL)
        try result.write(to: outputURL)
    }

    // MARK: - Error

    enum WAVError: Error, LocalizedError {
        case invalidHeader

        var errorDescription: String? {
            switch self {
            case .invalidHeader: return "Invalid WAV file header"
            }
        }
    }
}
