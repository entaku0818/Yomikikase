//
//  CloudTTSCleanup.swift
//  VoiceYourText
//
//  クラウドTTS撤去（v1.2.0 以降）に伴う UserDefaults の後片付け。
//

import Foundation

/// 撤去されたクラウドTTSが残した UserDefaults の値を、起動時に静かに捨てる。
///
/// - `PendingTTSJobs`: 未完了の音声生成ジョブID。サーバーへの問い合わせ経路ごと無くなったため
///   完了しようがなく、残したままだとファイル一覧の「生成中」表示が永久に消えない。
/// - `CloudTTSVoiceId`: クラウド音声の選択。選べる音声が無くなったため意味を持たない。
///
/// すでに生成・ダウンロード済みの音声ファイル（`Documents/audio/`）と
/// Core Data の `ttsMode` は対象外。ユーザーの資産なので消さない。
enum CloudTTSCleanup {
    /// 撤去済み機能が使っていたキー。
    static let removedKeys = ["PendingTTSJobs", "CloudTTSVoiceId"]

    /// 残っていれば削除する。削除したキーの数を返す（テスト用）。
    @discardableResult
    static func run(store: UserDefaults = .standard) -> Int {
        var removed = 0
        for key in removedKeys where store.object(forKey: key) != nil {
            store.removeObject(forKey: key)
            removed += 1
        }
        return removed
    }
}
