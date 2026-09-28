//
//  ReviewRequestTests.swift
//  VoiceYourTextTests
//
//  Created by 遠藤拓弥 on 2026/04/08.
//

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

@MainActor
final class ReviewRequestTests: XCTestCase {

    override func setUp() {
        super.setUp()
        resetReviewDefaults()
    }

    override func tearDown() {
        super.tearDown()
        resetReviewDefaults()
    }

    private func resetReviewDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "ReviewRequestCount")
        defaults.removeObject(forKey: "SpeechCompletedCount")
        defaults.removeObject(forKey: "LastReviewRequestDate")
        defaults.removeObject(forKey: "HasAnsweredReviewPositively")
        defaults.removeObject(forKey: "InstallDate")
        defaults.removeObject(forKey: "AppLaunchCount")
    }

    // MARK: - 起動時判定（システムダイアログを直接呼ぶ）

    func test_初回起動ではレビューを呼ばないこと() {
        XCTAssertFalse(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 1, didShowAppOpenAd: false))
    }

    func test_2回目以降の起動ではレビューを呼ぶこと() {
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 2, didShowAppOpenAd: false))
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 3, didShowAppOpenAd: false))
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 50, didShowAppOpenAd: false))
    }

    func test_App_Open広告を出した起動ではレビューを呼ばないこと() {
        XCTAssertFalse(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 5, didShowAppOpenAd: true))
    }

    func test_起動回数のインクリメントとインストール日の初期化() {
        XCTAssertEqual(ReviewRequestPrompt.incrementLaunchCount(), 1)
        XCTAssertNotNil(UserDefaultsManager.shared.installDate)
        XCTAssertEqual(ReviewRequestPrompt.incrementLaunchCount(), 2)
        XCTAssertEqual(UserDefaultsManager.shared.appLaunchCount, 2)
    }

    func test_Speechesのonappearではレビュー事前確認を出さず起動回数も数えないこと() async {
        // onAppear はスキャン保存後のリスト再取得でも呼ばれるため、ここで判定すると
        // 表示されないアラートでカウントだけ消費していた
        UserDefaultsManager.shared.appLaunchCount = 1

        let store = TestStore(initialState: Speeches.State(currentText: "")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
            XCTAssertNil(state.alert)
        }

        XCTAssertEqual(UserDefaultsManager.shared.appLaunchCount, 1)
        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 0)
    }

    // MARK: - speechFinished

    func test_5回目読み上げ完了でレビューが表示されること() async {
        UserDefaultsManager.shared.reviewRequestCount = 0
        UserDefaultsManager.shared.speechCompletedCount = 4  // 次で5回目

        let store = TestStore(initialState: Speeches.State(currentText: "テスト")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.speechFinished) { state in
            state.alert = AlertState {
                TextState("review.title")
            } actions: {
                ButtonState(action: .send(.onGoodReview)) {
                    TextState("review.button.yes")
                }
                ButtonState(action: .send(.onBadReview)) {
                    TextState("review.button.no")
                }
            } message: {
                TextState("review.message.first")
            }
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 1)
        XCTAssertNotNil(UserDefaultsManager.shared.lastReviewRequestDate)
    }

    func test_2回目以降_completedCount2_ではレビューが表示されないこと() async {
        // completedCount=1, reviewRequestCount=1 の状態から speechFinished → completedCount==2
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 1

        let store = TestStore(initialState: Speeches.State(currentText: "テスト")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.speechFinished) { state in
            XCTAssertNil(state.alert)
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 1)
    }

    func test_直近でレビュー事前確認済みの場合は5回ごとの条件を満たしても表示されないこと() async {
        // 頻度制御(ReviewRequestConfig.minimumDaysBetweenPrompts)のテスト:
        // 5回ごとの条件自体は満たしていても、直近で表示済みなら再表示しない
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 9  // 次で10回目
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false
        UserDefaultsManager.shared.lastReviewRequestDate = Date()

        let store = TestStore(initialState: Speeches.State(currentText: "テスト")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.speechFinished) { state in
            XCTAssertNil(state.alert)
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 1)
    }

    func test_10回目読み上げ完了でもレビューが表示されること() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 9  // 次で10回目
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false

        let store = TestStore(initialState: Speeches.State(currentText: "テスト")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.speechFinished) { state in
            state.alert = AlertState {
                TextState("review.title")
            } actions: {
                ButtonState(action: .send(.onGoodReview)) {
                    TextState("review.button.yes")
                }
                ButtonState(action: .send(.onBadReview)) {
                    TextState("review.button.no")
                }
            } message: {
                TextState("review.message.reinstall")
            }
        }

        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 2)
    }
}
