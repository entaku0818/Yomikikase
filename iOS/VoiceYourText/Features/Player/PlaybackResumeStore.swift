//
//  PlaybackResumeStore.swift
//  VoiceYourText
//

import Foundation

/// 停止した位置を覚えておき、次の再生をその続きから始めるための保存先。
/// 保存済みファイル（fileId があるもの）だけ、画面を閉じても位置が残るよう UserDefaults に書く。
/// 位置は元の文章の UTF-16 オフセット（NSRange と同じ単位）。
struct PlaybackResumeStore {
    private static let key = "PlaybackResumePositions"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 文章が変わっていなければ、前回止めた位置を返す
    func position(fileId: UUID, text: String) -> Int? {
        guard let entry = entries()[fileId.uuidString],
              let offset = entry["offset"] as? Int,
              let hash = entry["hash"] as? String,
              hash == Self.fingerprint(text),
              Self.isResumable(offset, in: text) else { return nil }
        return offset
    }

    func save(_ offset: Int, fileId: UUID, text: String) {
        guard Self.isResumable(offset, in: text) else {
            clear(fileId: fileId)
            return
        }
        var all = entries()
        all[fileId.uuidString] = ["offset": offset, "hash": Self.fingerprint(text)]
        defaults.set(all, forKey: Self.key)
    }

    func clear(fileId: UUID) {
        var all = entries()
        guard all.removeValue(forKey: fileId.uuidString) != nil else { return }
        defaults.set(all, forKey: Self.key)
    }

    /// 先頭と末尾は「続き」ではないので覚えない
    static func isResumable(_ offset: Int, in text: String) -> Bool {
        offset > 0 && offset < text.utf16.count
    }

    /// utf16Offset から後ろの文章と、その開始位置（UTF-16）を返す。
    /// 絵文字や結合文字の途中を指していたら、その文字の先頭まで戻す
    static func remainder(of text: String, fromUTF16Offset offset: Int) -> (text: String, base: Int) {
        let nsText = text as NSString
        let clamped = min(max(offset, 0), nsText.length)
        guard clamped < nsText.length else { return ("", nsText.length) }
        let base = nsText.rangeOfComposedCharacterSequence(at: clamped).location
        return (nsText.substring(from: base), base)
    }

    private func entries() -> [String: [String: Any]] {
        defaults.dictionary(forKey: Self.key) as? [String: [String: Any]] ?? [:]
    }

    /// 起動をまたいでも同じ値になるハッシュ（String.hashValue は起動ごとに変わる）。FNV-1a 64bit
    static func fingerprint(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
