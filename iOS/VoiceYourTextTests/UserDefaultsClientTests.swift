//
//  UserDefaultsClientTests.swift
//  VoiceYourTextTests
//
//  QA: UserDefaultsClient のユニットテスト (Issue #54)
//  カバレッジ:
//   - liveValue: キー未設定時のデフォルト値（speechRate=0.5 / speechPitch=1.0 / 各種 nil・0・false）
//   - liveValue: set/get のラウンドトリップ（String / Bool / Float / Int / Date）
//   - setIsPremiumUser の PremiumStatusDidChange 通知発行
//   - pendingJob（辞書型 PendingTTSJobs）の set / get / clear と UUID 独立性
//   - testValue のデフォルト値
//
//  注意: liveValue は UserDefaults.standard を直接参照するため、テスト対象キーを
//  setUp / tearDown で必ずクリアしてテスト間の汚染を防ぐ。

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

final class UserDefaultsClientTests: XCTestCase {

    private static let keys = [
        "LanguageSetting", "SelectedVoiceIdentifier", "CloudTTSVoiceId",
        "SpeechRate", "SpeechPitch",
        "IsPremiumUser", "PremiumPurchaseDate",
        "KokoroEnabled", "KokoroVoice",
        "HasCompletedOnboarding",
        "SpeechCompletedCount", "AppLaunchCount", "InstallDate",
        "ReviewRequestCount", "LastReviewRequestDate", "HasAnsweredReviewPositively",
        "PendingTTSJobs"
    ]

    private func clearKeys() {
        let d = UserDefaults.standard
        for key in Self.keys { d.removeObject(forKey: key) }
    }

    override func setUp() {
        super.setUp()
        clearKeys()
    }

    override func tearDown() {
        clearKeys()
        super.tearDown()
    }

    // MARK: - デフォルト値（キー未設定）

    func test_live_defaults_whenUnset() {
        let client = UserDefaultsClient.liveValue
        XCTAssertNil(client.languageSetting())
        XCTAssertNil(client.selectedVoiceIdentifier())
        XCTAssertNil(client.cloudTTSVoiceId())
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
        let client = UserDefaultsClient.liveValue
        client.setLanguageSetting("ja")
        client.setSelectedVoiceIdentifier("com.apple.voice.x")
        client.setCloudTTSVoiceId("ja-JP-Wavenet-A")
        client.setKokoroVoice("jf_alpha")

        XCTAssertEqual(client.languageSetting(), "ja")
        XCTAssertEqual(client.selectedVoiceIdentifier(), "com.apple.voice.x")
        XCTAssertEqual(client.cloudTTSVoiceId(), "ja-JP-Wavenet-A")
        XCTAssertEqual(client.kokoroVoice(), "jf_alpha")
    }

    // MARK: - Float ラウンドトリップ（デフォルト分岐外の値）

    func test_live_floatRoundTrips() {
        let client = UserDefaultsClient.liveValue
        client.setSpeechRate(0.75)
        client.setSpeechPitch(1.5)
        XCTAssertEqual(client.speechRate(), 0.75, accuracy: 0.0001)
        XCTAssertEqual(client.speechPitch(), 1.5, accuracy: 0.0001)
    }

    // MARK: - Bool ラウンドトリップ

    func test_live_boolRoundTrips() {
        let client = UserDefaultsClient.liveValue
        client.setKokoroEnabled(true)
        client.setHasCompletedOnboarding(true)
        client.setHasAnsweredReviewPositively(true)
        XCTAssertTrue(client.kokoroEnabled())
        XCTAssertTrue(client.hasCompletedOnboarding())
        XCTAssertTrue(client.hasAnsweredReviewPositively())
    }

    // MARK: - Int ラウンドトリップ

    func test_live_intRoundTrips() {
        let client = UserDefaultsClient.liveValue
        client.setSpeechCompletedCount(3)
        client.setAppLaunchCount(10)
        client.setReviewRequestCount(2)
        XCTAssertEqual(client.speechCompletedCount(), 3)
        XCTAssertEqual(client.appLaunchCount(), 10)
        XCTAssertEqual(client.reviewRequestCount(), 2)
    }

    // MARK: - Date ラウンドトリップ

    func test_live_dateRoundTrips() {
        let client = UserDefaultsClient.liveValue
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
        let client = UserDefaultsClient.liveValue
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

    // MARK: - pendingJob（辞書型管理）

    func test_pendingJob_setGetClear() {
        let client = UserDefaultsClient.liveValue
        let uuid = UUID()

        XCTAssertNil(client.pendingJobId(uuid))

        client.setPendingJob(uuid, "job-123")
        XCTAssertEqual(client.pendingJobId(uuid), "job-123")

        client.clearPendingJob(uuid)
        XCTAssertNil(client.pendingJobId(uuid))
    }

    func test_pendingJob_multipleUUIDsAreIndependent() {
        let client = UserDefaultsClient.liveValue
        let a = UUID()
        let b = UUID()

        client.setPendingJob(a, "job-a")
        client.setPendingJob(b, "job-b")

        XCTAssertEqual(client.pendingJobId(a), "job-a")
        XCTAssertEqual(client.pendingJobId(b), "job-b")

        // 片方をクリアしても他方は残る
        client.clearPendingJob(a)
        XCTAssertNil(client.pendingJobId(a))
        XCTAssertEqual(client.pendingJobId(b), "job-b")
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
        XCTAssertNil(client.pendingJobId(UUID()))
    }
}
