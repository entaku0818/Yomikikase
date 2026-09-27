import CryptoKit
import Foundation

/// キャラ音声で作った音声を端末に保存する。
///
/// 同じ文・同じ声・同じ速度なら保存済みの音声を再生し、サーバーを呼ばない（＝月の文字数を使わない）。
/// Caches に置くので、端末の空き容量が少ないと OS に消されることがある（そのときは作り直す）。
struct VoicevoxAudioCache {
    let directory: URL

    static let live: VoicevoxAudioCache = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return VoicevoxAudioCache(directory: caches.appendingPathComponent("voicevox", isDirectory: true))
    }()

    static func key(text: String, speakerId: Int, speedScale: Double) -> String {
        // 速度は小数第2位まで（0.5刻みの設定なので十分）
        let material = "\(speakerId)|\(String(format: "%.2f", speedScale))|\(text)"
        return SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func load(text: String, speakerId: Int, speedScale: Double) -> Data? {
        try? Data(contentsOf: fileURL(text: text, speakerId: speakerId, speedScale: speedScale))
    }

    func store(_ data: Data, text: String, speakerId: Int, speedScale: Double) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(text: text, speakerId: speakerId, speedScale: speedScale), options: .atomic)
        } catch {
            // 保存に失敗しても再生はできる。次回また作るだけ
            errorLog("[VOICEVOX] cache write failed: \(error)")
        }
    }

    /// 保存している音声の合計サイズ（バイト）
    func totalSize() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func fileURL(text: String, speakerId: Int, speedScale: Double) -> URL {
        directory.appendingPathComponent(Self.key(text: text, speakerId: speakerId, speedScale: speedScale) + ".m4a")
    }
}
