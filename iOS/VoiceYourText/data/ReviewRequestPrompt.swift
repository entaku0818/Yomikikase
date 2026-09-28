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
/// 毎起動で呼ぶとその3回をインストール直後に使い切るため、アプリ側でも最低間隔を空ける。
enum ReviewRequestConfig {
    /// 何回目の起動からシステムのレビューダイアログを直接呼ぶか（起動時判定）。事前確認は挟まない。
    static let launchReviewMinimumCount = 2

    /// 前回呼んでから最低何日空けるか。Appleの年3回枠を、使い込んだ時期にも残しておくため約3ヶ月にする。
    static let launchReviewMinimumDays = 90

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
    /// 前回呼んでから launchReviewMinimumDays 日経っていなければ呼ばない。
    static func shouldRequestOnLaunch(
        launchCount: Int,
        didShowAppOpenAd: Bool,
        lastRequestDate: Date?,
        now: Date = Date()
    ) -> Bool {
        guard launchCount >= ReviewRequestConfig.launchReviewMinimumCount, !didShowAppOpenAd else {
            return false
        }
        guard let lastRequestDate else {
            return true
        }
        let days = Calendar.current.dateComponents([.day], from: lastRequestDate, to: now).day ?? 0
        return days >= ReviewRequestConfig.launchReviewMinimumDays
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
        guard shouldRequestOnLaunch(
            launchCount: launchCount,
            didShowAppOpenAd: didShowAppOpenAd,
            lastRequestDate: UserDefaultsManager.shared.lastReviewRequestDate
        ) else {
            return
        }
        try? await Task.sleep(nanoseconds: ReviewRequestConfig.launchReviewDelayNanoseconds)
        UserDefaultsManager.shared.lastReviewRequestDate = Date()
        analytics.logEvent("review_request_system", ["trigger": "launch", "launch_count": launchCount])
        requestSystemReview()
    }
}
