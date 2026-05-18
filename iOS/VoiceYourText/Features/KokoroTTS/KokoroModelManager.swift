import Foundation

enum KokoroDownloadStatus: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)
}

actor KokoroModelManager {
    static let shared = KokoroModelManager()

    private let modelFileName = "kokoro-v1_0.safetensors"
    private let voicesFileName = "voices.npz"

    // GitHub LFS media CDN（raw URLはLFSポインタを返すためmedia.githubusercontent.comを使用）
    private let modelURL = URL(string: "https://media.githubusercontent.com/media/mlalma/KokoroTestApp/main/Resources/kokoro-v1_0.safetensors")!
    private let voicesURL = URL(string: "https://media.githubusercontent.com/media/mlalma/KokoroTestApp/main/Resources/voices.npz")!

    private(set) var status: KokoroDownloadStatus = .notDownloaded
    private var statusContinuations: [UUID: AsyncStream<KokoroDownloadStatus>.Continuation] = [:]

    private init() {
        if Self.checkDownloaded() { status = .downloaded }
    }

    func statusStream() -> AsyncStream<KokoroDownloadStatus> {
        AsyncStream { continuation in
            let id = UUID()
            statusContinuations[id] = continuation
            continuation.yield(status)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    func download() async throws {
        guard !isDownloaded() else {
            updateStatus(.downloaded)
            return
        }
        let dir = storageDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // voices.npz は軽いので先にダウンロード
        if !FileManager.default.fileExists(atPath: dir.appending(path: voicesFileName).path) {
            let (voicesData, _) = try await session.data(from: voicesURL)
            try voicesData.write(to: dir.appending(path: voicesFileName))
        }

        // モデル本体（~600MB）をチャンク単位でダウンロード
        updateStatus(.downloading(progress: 0))
        let dest = dir.appending(path: modelFileName)
        let tempDest = dir.appending(path: modelFileName + ".tmp")
        // 失敗時に中途半端なファイルが残らないよう一時ファイルに書いてから移動
        try? FileManager.default.removeItem(at: tempDest)
        FileManager.default.createFile(atPath: tempDest.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempDest)
        do {
            let (asyncBytes, response) = try await session.bytes(from: modelURL)
            let totalBytes = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Length")
                .flatMap { Int64($0) } ?? 0

            var downloaded: Int64 = 0
            var buffer = Data(capacity: 4 * 1_048_576)  // 4MB バッファ
            for try await byte in asyncBytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= 4 * 1_048_576 {
                    handle.write(buffer)
                    downloaded += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    if totalBytes > 0 {
                        updateStatus(.downloading(progress: Double(downloaded) / Double(totalBytes)))
                    }
                }
            }
            if !buffer.isEmpty {
                handle.write(buffer)
            }
            try handle.close()
            // 完了後に正規ファイル名へ移動（アトミック）
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempDest, to: dest)
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: tempDest)
            throw error
        }
        updateStatus(.downloaded)
    }

    // タイムアウト設定済みセッション（リクエスト30秒・リソース3600秒）
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        return URLSession(configuration: config)
    }()

    func modelFileURL() -> URL? {
        let url = storageDirectory().appending(path: modelFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func voicesFileURL() -> URL? {
        let url = storageDirectory().appending(path: voicesFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated func isDownloaded() -> Bool {
        Self.checkDownloaded()
    }

    nonisolated static func checkDownloaded() -> Bool {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KokoroTTS")
        let modelPath = dir.appending(path: "kokoro-v1_0.safetensors").path
        let voicesPath = dir.appending(path: "voices.npz").path
        return FileManager.default.fileExists(atPath: modelPath)
            && FileManager.default.fileExists(atPath: voicesPath)
    }

    func deleteModel() throws {
        let dir = storageDirectory()
        for name in [modelFileName, voicesFileName] {
            let path = dir.appending(path: name).path
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
        updateStatus(.notDownloaded)
    }

    // MARK: - Private

    private func storageDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KokoroTTS")
    }

    private func updateStatus(_ newStatus: KokoroDownloadStatus) {
        status = newStatus
        for cont in statusContinuations.values { cont.yield(newStatus) }
    }

    private func removeContinuation(id: UUID) {
        statusContinuations.removeValue(forKey: id)
    }
}
