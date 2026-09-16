import Foundation

enum KokoroDownloadStatus: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)
}

actor KokoroModelManager {
    static let shared = KokoroModelManager()

    static let modelFileName = "kokoro-v1_0.safetensors"
    static let voicesFileName = "voices.npz"

    /// モデル/ボイスファイルを保存する Application Support 配下のディレクトリ。
    /// static（checkDownloaded）とインスタンス（download 等）双方が同じパス解決を
    /// 共有できるよう一元化している。
    static func storageDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KokoroTTS")
    }

    /// モデル本体ダウンロード時のチャンクバッファサイズ（4 MB）。
    private let downloadBufferSize = 4 * 1_048_576

    // モデル本体は第三者リポジトリの GitHub LFS media CDN
    // （raw URL は LFS ポインタを返すため media.githubusercontent.com を使う）
    private let modelURL = URL(string: "https://media.githubusercontent.com/media/mlalma/KokoroTestApp/main/Resources/kokoro-v1_0.safetensors")!

    // ボイス埋め込みは自前ホスト（Firebase Hosting）。理由は2つ:
    //   1. 従来の media.githubusercontent.com の voices.npz は LFS 管理から外れて 404 になった
    //   2. その中身は英語28音声のみで、アプリが公開している jf_alpha / jm_kumo が
    //      1つも入っておらず、日本語 Kokoro が実行時に必ず失敗していた
    // 中身を変えるときは v2 を作り、古いクライアントが見る v1 は消さないこと。
    // 再生成は scripts/build_kokoro_voices.py。
    private let voicesURL = URL(string: "https://voiceyourtext.web.app/kokoro/voices-v1.npz")!

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
        let dir = Self.storageDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // voices.npz は軽いので先にダウンロード。
        // ここで HTTP ステータスと ZIP マジックバイトを検証してから書き込む。
        // 検証しないと、404 の本文（HTMLやカラ）をそのまま voices.npz として保存したうえ
        // 約300MBのモデル本体を最後まで落としてしまい、しかも checkDownloaded() が
        // false を返すので「DL済みなのに Kokoro が使えない」状態になる。
        if !FileManager.default.fileExists(atPath: dir.appending(path: Self.voicesFileName).path) {
            let (voicesData, voicesResponse) = try await session.data(from: voicesURL)
            let statusCode = (voicesResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else {
                throw KokoroError.synthesisFailure("ボイスファイルの取得に失敗しました (HTTP \(statusCode))")
            }
            guard Self.isValidVoicesHeader(voicesData.prefix(4)) else {
                throw KokoroError.synthesisFailure("ボイスファイルが壊れています")
            }
            try voicesData.write(to: dir.appending(path: Self.voicesFileName))
        }

        // モデル本体（~600MB）をチャンク単位でダウンロード
        updateStatus(.downloading(progress: 0))
        let dest = dir.appending(path: Self.modelFileName)
        let tempDest = dir.appending(path: Self.modelFileName + ".tmp")
        // 失敗時に中途半端なファイルが残らないよう一時ファイルに書いてから移動
        try? FileManager.default.removeItem(at: tempDest)
        FileManager.default.createFile(atPath: tempDest.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempDest)
        do {
            let (asyncBytes, response) = try await session.bytes(from: modelURL)
            let totalBytes = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Length")
                .flatMap { Int64($0) } ?? 0

            var downloaded: Int64 = 0
            var buffer = Data(capacity: downloadBufferSize)
            for try await byte in asyncBytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= downloadBufferSize {
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
        let url = Self.storageDirectory().appending(path: Self.modelFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func voicesFileURL() -> URL? {
        let url = Self.storageDirectory().appending(path: Self.voicesFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated func isDownloaded() -> Bool {
        Self.checkDownloaded()
    }

    nonisolated static func checkDownloaded() -> Bool {
        let dir = storageDirectory()
        let modelURL = dir.appending(path: modelFileName)
        let voicesURL = dir.appending(path: voicesFileName)
        guard FileManager.default.fileExists(atPath: modelURL.path),
              FileManager.default.fileExists(atPath: voicesURL.path) else { return false }
        // voices.npz が ZIP マジックバイト(PK\x03\x04)で始まるか検証
        // GitHub LFS ポインタが保存された場合はテキストファイルになる
        guard let handle = try? FileHandle(forReadingFrom: voicesURL),
              let header = try? handle.read(upToCount: 4) else { return false }
        try? handle.close()
        return isValidVoicesHeader(header)
    }

    /// voices.npz 先頭バイトが ZIP アーカイブ (PK\x03\x04) かどうかを判定する純粋関数。
    /// GitHub LFS のポインタがそのまま保存された場合はテキスト (例: "version ...") に
    /// なるため false を返す。モデルロードに依存せずユニットテストできるよう切り出している。
    nonisolated static func isValidVoicesHeader(_ header: Data?) -> Bool {
        guard let header, header.count >= 2 else {
            return false
        }
        return header[header.startIndex] == 0x50 && header[header.startIndex + 1] == 0x4B
    }

    func deleteModel() throws {
        let dir = Self.storageDirectory()
        for name in [Self.modelFileName, Self.voicesFileName] {
            let path = dir.appending(path: name).path
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
        updateStatus(.notDownloaded)
    }

    // MARK: - Private

    private func updateStatus(_ newStatus: KokoroDownloadStatus) {
        status = newStatus
        for cont in statusContinuations.values { cont.yield(newStatus) }
    }

    private func removeContinuation(id: UUID) {
        statusContinuations.removeValue(forKey: id)
    }
}
