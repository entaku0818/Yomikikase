//
//  FileLimitsManager.swift
//  VoiceYourText
//
//  Created by Claude on 2025/01/03.
//

import Foundation

/// ファイル数制限を管理するマネージャー
enum FileLimitsManager {
    /// 無料版の最大ファイル数（PDF + テキストファイルの合計）
    static let maxFreeFileCount = 5

    /// 現在のPDFファイル数を取得
    static func getCurrentPDFCount() -> Int {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return fileURLs.filter { $0.pathExtension.lowercased() == "pdf" }.count
        } catch {
            return 0
        }
    }

    /// 現在のテキストファイル数を取得（デフォルトファイルを除く）
    static func getCurrentTextFileCount() -> Int {
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
        let speeches = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)
        // デフォルトファイルを除外してカウント
        return speeches.filter { !$0.isDefault }.count
    }

    /// 現在の合計ファイル数を取得
    static func getCurrentTotalFileCount() -> Int {
        return getCurrentPDFCount() + getCurrentTextFileCount()
    }

    /// 無料版のファイル制限に達しているかどうか
    static func hasReachedFreeLimit() -> Bool {
        guard !UserDefaultsManager.shared.isPremiumUser else { return false }
        return getCurrentTotalFileCount() >= maxFreeFileCount
    }

    /// 残りの登録可能ファイル数
    static func remainingFileCount() -> Int {
        if UserDefaultsManager.shared.isPremiumUser {
            return Int.max
        }
        return max(0, maxFreeFileCount - getCurrentTotalFileCount())
    }
}
