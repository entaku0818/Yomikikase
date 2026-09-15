//
//  AppOpenAdGateTests.swift
//  VoiceYourTextTests
//
//  App Open広告の表示判定ロジックのテスト。
//  共通ルール（起動N回に1回 / 課金ユーザー除外）が壊れていないことを守る。
//

import XCTest
@testable import VoiceYourText

final class AppOpenAdGateTests: XCTestCase {

    // MARK: - 起動N回に1回のゲート（共通ルール2）

    func testDoesNotShowOnFirstLaunch() {
        // 初回起動で全画面広告を出すと体験が悪いので出さない
        XCTAssertFalse(
            AppOpenAdGate.shouldShow(
                launchCount: 1,
                isPremiumUser: false,
                hasCompletedOnboarding: true
            )
        )
    }

    func testShowsOnEveryFifthLaunch() {
        for launchCount in 1...20 {
            let shouldShow = AppOpenAdGate.shouldShow(
                launchCount: launchCount,
                isPremiumUser: false,
                hasCompletedOnboarding: true
            )
            let isFifth = launchCount % 5 == 0
            XCTAssertEqual(
                shouldShow, isFifth,
                "launchCount=\(launchCount) では \(isFifth ? "表示" : "非表示") が期待値"
            )
        }
    }

    func testDefaultIntervalIsFive() {
        // 初期値が変わったらテストも意図的に直す
        XCTAssertEqual(AppOpenAdGate.defaultShowEveryNLaunches, 5)
    }

    func testCustomIntervalIsRespected() {
        XCTAssertTrue(
            AppOpenAdGate.shouldShow(
                launchCount: 3,
                isPremiumUser: false,
                hasCompletedOnboarding: true,
                showEveryNLaunches: 3
            )
        )
        XCTAssertFalse(
            AppOpenAdGate.shouldShow(
                launchCount: 4,
                isPremiumUser: false,
                hasCompletedOnboarding: true,
                showEveryNLaunches: 3
            )
        )
    }

    // MARK: - 課金ユーザー除外（共通ルール4）

    func testNeverShowsToPremiumUser() {
        // 表示回（5の倍数）であっても課金ユーザーには出さない
        for launchCount in [5, 10, 15, 100] {
            XCTAssertFalse(
                AppOpenAdGate.shouldShow(
                    launchCount: launchCount,
                    isPremiumUser: true,
                    hasCompletedOnboarding: true
                ),
                "launchCount=\(launchCount) で課金ユーザーに表示されてしまっている"
            )
        }
    }

    // MARK: - オンボーディング中は出さない

    func testDoesNotShowDuringOnboarding() {
        XCTAssertFalse(
            AppOpenAdGate.shouldShow(
                launchCount: 5,
                isPremiumUser: false,
                hasCompletedOnboarding: false
            )
        )
    }

    // MARK: - 異常値

    func testZeroOrNegativeLaunchCountDoesNotShow() {
        XCTAssertFalse(
            AppOpenAdGate.shouldShow(
                launchCount: 0,
                isPremiumUser: false,
                hasCompletedOnboarding: true
            )
        )
        XCTAssertFalse(
            AppOpenAdGate.shouldShow(
                launchCount: -5,
                isPremiumUser: false,
                hasCompletedOnboarding: true
            )
        )
    }

    func testZeroIntervalDoesNotShow() {
        // 0除算を避ける
        XCTAssertFalse(
            AppOpenAdGate.shouldShow(
                launchCount: 5,
                isPremiumUser: false,
                hasCompletedOnboarding: true,
                showEveryNLaunches: 0
            )
        )
    }

    // MARK: - カウンタキーが他機能と共有されていないこと（共通ルール3）

    func testLaunchCounterUsesDedicatedKey() {
        let defaults = UserDefaults.standard
        let key = "AppOpenAdLaunchCount"
        let original = defaults.object(forKey: key)
        defer {
            if let original {
                defaults.set(original, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let originalReviewCount = UserDefaultsManager.shared.reviewRequestCount
        let originalSpeechCount = UserDefaultsManager.shared.speechCompletedCount

        UserDefaultsManager.shared.appOpenAdLaunchCount = 42

        XCTAssertEqual(UserDefaultsManager.shared.appOpenAdLaunchCount, 42)
        // 他機能のカウンタを巻き込んでいないこと
        XCTAssertEqual(UserDefaultsManager.shared.reviewRequestCount, originalReviewCount)
        XCTAssertEqual(UserDefaultsManager.shared.speechCompletedCount, originalSpeechCount)
    }
}
