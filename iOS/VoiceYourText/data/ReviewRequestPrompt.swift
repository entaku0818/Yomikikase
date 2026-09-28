//
//  ReviewRequestPrompt.swift
//  VoiceYourText
//
//  レビュー依頼の発火条件と呼び出しを一箇所に集約する。
//  2回目以降の cold start で「満足していますか？」を1問だけ聞き、
//  はい → すぐシステムのレビューダイアログ / いいえ → お問い合わせ（FeedbackView）へ誘導する。
//

import Foundation
import StoreKit
import UIKit

/// レビュー依頼の発火条件を定数として集約したもの。
///
/// Appleは年3回までしかシステムダイアログを実際に表示しない（アプリ側では検知・制御できない）。
/// 毎起動で呼ぶとその3回をインストール直後に使い切るため、アプリ側でも最低間隔を空ける。
enum ReviewRequestConfig {
    /// 何回目の起動から満足度の確認を出すか（起動時判定）
    static let launchReviewMinimumCount = 2

    /// 前回確認を出してから最低何日空けるか。Appleの年3回枠を、使い込んだ時期にも残しておくため約3ヶ月にする。
    static let launchReviewMinimumDays = 90

    /// 起動から満足度の確認を出すまでの待ち時間（画面が落ち着いてから出す）
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

    /// この cold start で満足度の確認を出すべきか。
    /// App Open広告を出した起動では、全画面広告の上に被せないよう呼ばない。
    /// 前回出してから launchReviewMinimumDays 日経っていなければ出さない。
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

    /// 起動時判定: 条件を満たせば少し待ってから true を返す（呼び出し側で満足度の確認を表示する）。
    @MainActor
    static func shouldPromptOnLaunch(launchCount: Int, didShowAppOpenAd: Bool, analytics: AnalyticsClient) async -> Bool {
        guard shouldRequestOnLaunch(
            launchCount: launchCount,
            didShowAppOpenAd: didShowAppOpenAd,
            lastRequestDate: UserDefaultsManager.shared.lastReviewRequestDate
        ) else {
            return false
        }
        try? await Task.sleep(nanoseconds: ReviewRequestConfig.launchReviewDelayNanoseconds)
        UserDefaultsManager.shared.lastReviewRequestDate = Date()
        analytics.logEvent("review_prompt_shown", ["trigger": "launch", "launch_count": launchCount])
        return true
    }

    /// 満足度の確認への回答。はい → システムのレビューダイアログ（実際に出すかは Apple が決める）。
    /// いいえの場合のお問い合わせ画面の表示は呼び出し側で行う。
    static func answerPrompt(satisfied: Bool, analytics: AnalyticsClient) {
        analytics.logEvent("review_prompt_answer", ["answer": satisfied ? "yes" : "no"])
        guard satisfied else {
            return
        }
        analytics.logEvent("review_request_system", ["trigger": "launch"])
        requestSystemReview()
    }
}
