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

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    func test_初回起動ではレビューを呼ばないこと() {
        XCTAssertFalse(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 1, didShowAppOpenAd: false, lastRequestDate: nil))
    }

    func test_2回目以降の起動で未依頼ならレビューを呼ぶこと() {
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 2, didShowAppOpenAd: false, lastRequestDate: nil))
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 50, didShowAppOpenAd: false, lastRequestDate: nil))
    }

    func test_App_Open広告を出した起動ではレビューを呼ばないこと() {
        XCTAssertFalse(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 5, didShowAppOpenAd: true, lastRequestDate: nil))
    }

    func test_前回から90日未満ならレビューを呼ばないこと() {
        XCTAssertFalse(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 3, didShowAppOpenAd: false, lastRequestDate: Date()))
        XCTAssertFalse(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 3, didShowAppOpenAd: false, lastRequestDate: daysAgo(89)))
    }

    func test_前回から90日以上経っていればレビューを呼ぶこと() {
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 3, didShowAppOpenAd: false, lastRequestDate: daysAgo(90)))
        XCTAssertTrue(ReviewRequestPrompt.shouldRequestOnLaunch(launchCount: 3, didShowAppOpenAd: false, lastRequestDate: daysAgo(400)))
    }

    func test_起動回数のインクリメントとインストール日の初期化() {
        XCTAssertEqual(ReviewRequestPrompt.incrementLaunchCount(), 1)
        XCTAssertNotNil(UserDefaultsManager.shared.installDate)
        XCTAssertEqual(ReviewRequestPrompt.incrementLaunchCount(), 2)
        XCTAssertEqual(UserDefaultsManager.shared.appLaunchCount, 2)
    }

    func test_満足していないと答えたらシステムのレビューダイアログを呼ばないこと() {
        let events = LockIsolated<[String]>([])
        let analytics = AnalyticsClient(
            logEvent: { name, _ in events.withValue { $0.append(name) } },
            setUserProperty: { _, _ in }
        )

        ReviewRequestPrompt.answerPrompt(satisfied: false, analytics: analytics)

        XCTAssertEqual(events.value, ["review_prompt_answer"])
    }

    func test_Speechesのonappearでは起動回数を数えないこと() async {
        // onAppear はスキャン保存後のリスト再取得でも呼ばれるため、起動時判定を置かない
        UserDefaultsManager.shared.appLaunchCount = 1

        let store = TestStore(initialState: Speeches.State(currentText: "")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        XCTAssertEqual(UserDefaultsManager.shared.appLaunchCount, 1)
        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, 0)
    }
}
