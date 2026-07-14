//
//  ReviewRequestPrompt.swift
//  VoiceYourText
//
//  レビュー依頼まわりの発火条件・頻度制御・共通UIロジックを一箇所に集約する。
//  「このアプリどうですか？」という事前確認(Yes/No)を経てから
//  SKStoreReviewController.requestReview を呼ぶ既存フローを維持する。
//  Noを選んだユーザーはFeedbackViewに誘導し、意見を別途収集する。
//

import Foundation
import StoreKit
import SwiftUI
import UIKit
import ComposableArchitecture

/// レビュー依頼の発火条件を定数として集約したもの。
///
/// Appleは年3回までしかシステムダイアログを実際に表示しない（アプリ側では検知・制御できない仕様のため、
/// それ自体をここで再実装する必要はない）。アプリ側の役割は
/// 「ポジティブ体験の直後」に事前確認を出すタイミングを選ぶことと、
/// 同じユーザーに何度も事前確認ダイアログを見せすぎないよう独自に間隔を空けることの2点。
enum ReviewRequestConfig {
    /// 何回目の起動で初回の事前確認を検討するか（インストール直後よりは少し使ってもらった後、の意図）
    static let secondLaunchTrigger = 2

    /// インストールから何日後に、まだ一度も表示していなければ事前確認を検討するか
    static let installDaysTrigger = 2

    /// 起動ベースの再表示条件（onAppearの「reappear」分岐）: 前回表示から最低何日空けるか
    static let reappearMinDays = 3

    /// 読み上げ完了が何回ごとに事前確認を検討するか（コア体験＝読み上げを聴けた直後）
    /// SpeechView（テキスト直接入力）とPDFReader（PDF読み上げ）の両方で共通して使う。
    static let speechCompletionInterval = 5

    /// 読み上げ完了トリガー専用の頻度制御: 前回の事前確認表示から最低何日空けるか。
    /// speechCompletionIntervalごとに毎回律儀に出すと、ヘビーユーザーほど短期間に
    /// 何度も同じダイアログを見ることになるため、これで間隔を空ける。
    static let minimumDaysBetweenPrompts = 30
}

/// レビュー事前確認ダイアログのボタンアクション。SpeechView/PDFReaderView など、
/// 複数のReducerから同じ確認フローを再利用できるよう共通の型として定義する。
enum ReviewPromptAction: Equatable, Sendable {
    case onGoodReview
    case onBadReview
    case onAddReview
}

enum ReviewRequestPrompt {
    static func alertState(messageKey: String) -> AlertState<ReviewPromptAction> {
        AlertState {
            TextState("review.title")
        } actions: {
            ButtonState(action: .send(.onGoodReview)) {
                TextState("review.button.yes")
            }
            ButtonState(action: .send(.onBadReview)) {
                TextState("review.button.no")
            }
        } message: {
            // messageKeyは実行時のStringのため、TextState(String)（非ローカライズ）に解決されないよう
            // 明示的にLocalizedStringKeyへ変換してLocalizable.xcstringsの翻訳を効かせる
            TextState(LocalizedStringKey(messageKey))
        }
    }

    static let thanksAlert = AlertState<ReviewPromptAction>(
        title: TextState("review.thanks.title"),
        message: TextState("review.thanks.message"),
        dismissButton: .default(TextState("OK"), action: .send(.onAddReview))
    )

    /// 「はい」を押した際にhasAnsweredReviewPositivelyを立て、サンクス画面用のAlertStateを返す。
    static func markAnsweredPositively() -> AlertState<ReviewPromptAction> {
        UserDefaultsManager.shared.hasAnsweredReviewPositively = true
        return thanksAlert
    }

    /// サンクス画面の「OK」タップ時、実際のシステムレビューダイアログを呼び出す。
    static func requestSystemReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// 読み上げ完了イベント用の判定。completedCountは呼び出し側で更新済みの最新値を渡す。
    /// speechCompletionIntervalの倍数に達し、まだ「はい」を押しておらず、
    /// 前回の事前確認表示からminimumDaysBetweenPrompts以上経過していれば表示する。
    static func alertForSpeechCompletion(completedCount: Int, analytics: AnalyticsClient) -> AlertState<ReviewPromptAction>? {
        guard completedCount % ReviewRequestConfig.speechCompletionInterval == 0,
              !UserDefaultsManager.shared.hasAnsweredReviewPositively,
              !isThrottled(minimumDays: ReviewRequestConfig.minimumDaysBetweenPrompts)
        else { return nil }

        let isFirstShow = completedCount == ReviewRequestConfig.speechCompletionInterval
        let trigger = isFirstShow ? "speech_completed_first" : "speech_completed_\(completedCount)"
        let messageKey = isFirstShow ? "review.message.first" : "review.message.reinstall"

        markShown(trigger: trigger, analytics: analytics)
        return alertState(messageKey: messageKey)
    }

    /// 前回の表示から指定日数以上経っていなければtrue（頻度制御）
    static func isThrottled(minimumDays: Int, now: Date = Date()) -> Bool {
        guard let lastDate = UserDefaultsManager.shared.lastReviewRequestDate else {
            return false
        }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: now).day ?? 0
        return days < minimumDays
    }

    static func markShown(trigger: String, analytics: AnalyticsClient) {
        UserDefaultsManager.shared.reviewRequestCount += 1
        UserDefaultsManager.shared.lastReviewRequestDate = Date()
        analytics.logEvent("review_request_shown", ["trigger": trigger])
    }
}
