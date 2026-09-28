//
//  ReviewRequestPrompt.swift
//  VoiceYourText
//
//  レビュー依頼の発火条件と呼び出しを一箇所に集約する。
//  2回目以降の cold start でシステムのレビューダイアログを直接呼ぶ（事前確認は挟まない）。
//

import Foundation
import StoreKit
import UIKit

/// レビュー依頼の発火条件を定数として集約したもの。
///
/// Appleは年3回までしかシステムダイアログを実際に表示しない（アプリ側では検知・制御できない）。
/// アプリ側は呼ぶタイミングだけを決め、間引きは Apple に任せる。
enum ReviewRequestConfig {
    /// 何回目の起動からシステムのレビューダイアログを直接呼ぶか（起動時判定）。
    /// 事前確認を挟まず、この回以降は毎回の cold start で呼び、表示の間引きは Apple（年3回）に任せる。
    /// シンプル録音（2回目以降の録音保存で毎回呼ぶ）と同じ考え方で、評価件数が桁違いに多い実績がある。
    static let launchReviewMinimumCount = 2

    /// 起動からシステムダイアログを呼ぶまでの待ち時間（画面が落ち着いてから出す）
    static let launchReviewDelayNanoseconds: UInt64 = 2_000_000_000
}

enum ReviewRequestPrompt {
    /// システムのレビューダイアログを呼び出す。
    static func requestSystemReview() {
        let scenes = UIApplication.shared.connectedScenes
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let scene = activeScene as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// この cold start でシステムのレビューダイアログを呼ぶべきか。
    /// App Open広告を出した起動では、全画面広告の上に被せないよう呼ばない。
    static func shouldRequestOnLaunch(launchCount: Int, didShowAppOpenAd: Bool) -> Bool {
        launchCount >= ReviewRequestConfig.launchReviewMinimumCount && !didShowAppOpenAd
    }

    /// 起動回数をインクリメントして返す。cold start ごとに1回だけ呼ぶ。
    @discardableResult
    static func incrementLaunchCount() -> Int {
        let launchCount = UserDefaultsManager.shared.appLaunchCount + 1
        UserDefaultsManager.shared.appLaunchCount = launchCount
        if UserDefaultsManager.shared.installDate == nil {
            UserDefaultsManager.shared.installDate = Date()
        }
        return launchCount
    }

    /// 起動時判定: 条件を満たせば少し待ってからシステムのレビューダイアログを直接呼ぶ。
    /// 事前確認（はい/いいえ）は挟まない。実際に表示するかどうかは Apple 側が決める。
    @MainActor
    static func requestOnLaunchIfEligible(launchCount: Int, didShowAppOpenAd: Bool, analytics: AnalyticsClient) async {
        guard shouldRequestOnLaunch(launchCount: launchCount, didShowAppOpenAd: didShowAppOpenAd) else { return }
        try? await Task.sleep(nanoseconds: ReviewRequestConfig.launchReviewDelayNanoseconds)
        analytics.logEvent("review_request_system", ["trigger": "launch", "launch_count": launchCount])
        requestSystemReview()
    }
}
