//
//  UserDefaultsClientTests.swift
//  VoiceYourTextTests
//
//  QA: UserDefaultsClient のユニットテスト (Issue #54)
//  カバレッジ:
//   - liveValue: キー未設定時のデフォルト値（speechRate=0.5 / speechPitch=1.0 / 各種 nil・0・false）
//   - liveValue: set/get のラウンドトリップ（String / Bool / Float / Int / Date）
//   - setIsPremiumUser の PremiumStatusDidChange 通知発行
//   - testValue のデフォルト値
//
//  注意: UserDefaults.standard は使わない。テストホストのアプリが同じ standard に
//  書き込むうえ、検索ドメインに残った値は removeObject では消えず
//  test_live_defaults_whenUnset が常に落ちていた（#127）。
//  ここでは専用スイートを UserDefaultsClient.live(store:) に渡して完全に隔離する。
//  本番の liveValue は live(store: .standard) のままで挙動は変わらない。

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

final class UserDefaultsClientTests: XCTestCase {

    /// このテスト専用の UserDefaults スイート（standard から隔離する）
    private static let suiteName = "com.entaku.VoiceYourText.tests.UserDefaultsClientTests"
    private var suite: UserDefaults!

    /// テスト対象のクライアント。専用スイートを保存先にした live 実装。
    private var client: UserDefaultsClient { UserDefaultsClient.live(store: suite) }

    private static let keys = [
        "LanguageSetting", "SelectedVoiceIdentifier",
        "SpeechRate", "SpeechPitch",
        "IsPremiumUser", "PremiumPurchaseDate",
        "KokoroEnabled", "KokoroVoice",
        "HasCompletedOnboarding",
        "SpeechCompletedCount", "AppLaunchCount", "InstallDate",
        "ReviewRequestCount", "LastReviewRequestDate", "HasAnsweredReviewPositively"
    ]

    private func clearKeys() {
        suite.removePersistentDomain(forName: Self.suiteName)
        for key in Self.keys { suite.removeObject(forKey: key) }
    }

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: Self.suiteName)
        XCTAssertNotNil(suite, "テスト用スイートを作成できなかった")
        clearKeys()
    }

    override func tearDown() {
        clearKeys()
        suite = nil
        super.tearDown()
    }

    // MARK: - デフォルト値（キー未設定）

    func test_live_defaults_whenUnset() {
        XCTAssertNil(client.languageSetting())
        XCTAssertNil(client.selectedVoiceIdentifier())
        XCTAssertEqual(client.speechRate(), 0.5, accuracy: 0.0001)
        XCTAssertEqual(client.speechPitch(), 1.0, accuracy: 0.0001)
        XCTAssertFalse(client.isPremiumUser())
        XCTAssertNil(client.premiumPurchaseDate())
        XCTAssertFalse(client.kokoroEnabled())
        XCTAssertNil(client.kokoroVoice())
        XCTAssertFalse(client.hasCompletedOnboarding())
        XCTAssertEqual(client.speechCompletedCount(), 0)
        XCTAssertEqual(client.appLaunchCount(), 0)
        XCTAssertNil(client.installDate())
        XCTAssertEqual(client.reviewRequestCount(), 0)
        XCTAssertNil(client.lastReviewRequestDate())
        XCTAssertFalse(client.hasAnsweredReviewPositively())
    }

    // MARK: - String ラウンドトリップ

    func test_live_stringRoundTrips() {
        client.setLanguageSetting("ja")
        client.setSelectedVoiceIdentifier("com.apple.voice.x")
        client.setKokoroVoice("jf_alpha")

        XCTAssertEqual(client.languageSetting(), "ja")
        XCTAssertEqual(client.selectedVoiceIdentifier(), "com.apple.voice.x")
        XCTAssertEqual(client.kokoroVoice(), "jf_alpha")
    }

    // MARK: - Float ラウンドトリップ（デフォルト分岐外の値）

    func test_live_floatRoundTrips() {
        client.setSpeechRate(0.75)
        client.setSpeechPitch(1.5)
        XCTAssertEqual(client.speechRate(), 0.75, accuracy: 0.0001)
        XCTAssertEqual(client.speechPitch(), 1.5, accuracy: 0.0001)
    }

    // MARK: - Bool ラウンドトリップ

    func test_live_boolRoundTrips() {
        client.setKokoroEnabled(true)
        client.setHasCompletedOnboarding(true)
        client.setHasAnsweredReviewPositively(true)
        XCTAssertTrue(client.kokoroEnabled())
        XCTAssertTrue(client.hasCompletedOnboarding())
        XCTAssertTrue(client.hasAnsweredReviewPositively())
    }

    // MARK: - Int ラウンドトリップ

    func test_live_intRoundTrips() {
        client.setSpeechCompletedCount(3)
        client.setAppLaunchCount(10)
        client.setReviewRequestCount(2)
        XCTAssertEqual(client.speechCompletedCount(), 3)
        XCTAssertEqual(client.appLaunchCount(), 10)
        XCTAssertEqual(client.reviewRequestCount(), 2)
    }

    // MARK: - Date ラウンドトリップ

    func test_live_dateRoundTrips() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        client.setPremiumPurchaseDate(date)
        client.setInstallDate(date)
        client.setLastReviewRequestDate(date)

        XCTAssertEqual(
            client.premiumPurchaseDate()?.timeIntervalSince1970 ?? -1,
            date.timeIntervalSince1970, accuracy: 0.001
        )
        XCTAssertEqual(
            client.installDate()?.timeIntervalSince1970 ?? -1,
            date.timeIntervalSince1970, accuracy: 0.001
        )
        XCTAssertEqual(
            client.lastReviewRequestDate()?.timeIntervalSince1970 ?? -1,
            date.timeIntervalSince1970, accuracy: 0.001
        )
    }

    // MARK: - PremiumStatusDidChange 通知

    func test_setIsPremiumUser_persistsAndPostsNotification() {
        let expectation = expectation(
            forNotification: Notification.Name("PremiumStatusDidChange"),
            object: nil
        ) { notification in
            (notification.userInfo?["isPremium"] as? Bool) == true
        }

        client.setIsPremiumUser(true)

        XCTAssertTrue(client.isPremiumUser())
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - testValue のデフォルト

    func test_testValue_defaults() {
        let client = UserDefaultsClient.testValue
        XCTAssertNil(client.languageSetting())
        XCTAssertEqual(client.speechRate(), 0.5, accuracy: 0.0001)
        XCTAssertEqual(client.speechPitch(), 1.0, accuracy: 0.0001)
        XCTAssertFalse(client.isPremiumUser())
        XCTAssertFalse(client.kokoroEnabled())
        XCTAssertFalse(client.hasCompletedOnboarding())
        XCTAssertEqual(client.speechCompletedCount(), 0)
        XCTAssertEqual(client.appLaunchCount(), 0)
    }
}
