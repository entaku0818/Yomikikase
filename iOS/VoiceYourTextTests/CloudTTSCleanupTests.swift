//
//  CloudTTSCleanupTests.swift
//  VoiceYourTextTests
//
//  QA: クラウドTTS撤去に伴う UserDefaults 後片付けのユニットテスト
//  カバレッジ:
//   - 未完了ジョブID(PendingTTSJobs) / クラウド音声ID(CloudTTSVoiceId) が消えること
//   - 無関係なキーを巻き込まないこと（ユーザーの設定を壊さない）
//   - 何も無いときに冪等であること
//
//  注意: UserDefaults.standard は使わない。テストホストのアプリと同じドメインを
//  壊さないよう専用スイートを渡す（UserDefaultsClientTests と同じ方針）。
//

import XCTest
@testable import VoiceYourText

final class CloudTTSCleanupTests: XCTestCase {

    private static let suiteName = "com.entaku.VoiceYourText.tests.CloudTTSCleanupTests"
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: Self.suiteName)
        XCTAssertNotNil(suite, "テスト用スイートを作成できなかった")
        suite.removePersistentDomain(forName: Self.suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: Self.suiteName)
        suite = nil
        super.tearDown()
    }

    func test_未完了ジョブとクラウド音声IDが削除される() {
        suite.set(["\(UUID().uuidString)": "job-123"], forKey: "PendingTTSJobs")
        suite.set("ja-JP-Wavenet-A", forKey: "CloudTTSVoiceId")

        let removed = CloudTTSCleanup.run(store: suite)

        XCTAssertEqual(removed, 2)
        XCTAssertNil(suite.object(forKey: "PendingTTSJobs"))
        XCTAssertNil(suite.object(forKey: "CloudTTSVoiceId"))
    }

    func test_無関係なキーは残る() {
        suite.set(["id": "job-1"], forKey: "PendingTTSJobs")
        suite.set("ja", forKey: "LanguageSetting")
        suite.set("com.apple.voice.x", forKey: "SelectedVoiceIdentifier")
        suite.set(true, forKey: "KokoroEnabled")
        suite.set(0.75, forKey: "SpeechRate")

        CloudTTSCleanup.run(store: suite)

        XCTAssertEqual(suite.string(forKey: "LanguageSetting"), "ja")
        XCTAssertEqual(suite.string(forKey: "SelectedVoiceIdentifier"), "com.apple.voice.x")
        XCTAssertTrue(suite.bool(forKey: "KokoroEnabled"))
        XCTAssertEqual(suite.float(forKey: "SpeechRate"), 0.75, accuracy: 0.0001)
    }

    func test_対象キーが無ければ何もしない() {
        XCTAssertEqual(CloudTTSCleanup.run(store: suite), 0)
    }

    func test_二回実行しても安全() {
        suite.set("ja-JP-Wavenet-A", forKey: "CloudTTSVoiceId")

        XCTAssertEqual(CloudTTSCleanup.run(store: suite), 1)
        XCTAssertEqual(CloudTTSCleanup.run(store: suite), 0)
        XCTAssertNil(suite.object(forKey: "CloudTTSVoiceId"))
    }
}
