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
