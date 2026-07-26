//
//  PDFListFeatureTests.swift
//  VoiceYourTextTests
//

import XCTest
@testable import VoiceYourText

final class PDFListFeatureTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaultsManager.shared.isPremiumUser = false
    }

    override func tearDown() {
        UserDefaultsManager.shared.isPremiumUser = false
        super.tearDown()
    }

    func test_プレミアムユーザーはhasReachedFreeLimitがfalseを返すこと() {
        let state = PDFListFeature.State(isPremiumUser: true)
        XCTAssertFalse(state.hasReachedFreeLimit)
    }

    func test_無料ユーザーの判定がFileLimitsManagerと一致すること() {
        UserDefaultsManager.shared.isPremiumUser = false
        let state = PDFListFeature.State(isPremiumUser: false)

        // PDF単独3件ではなく、他の登録画面と同じ「PDF・テキスト合計5件」の制限を使うこと
        XCTAssertEqual(state.hasReachedFreeLimit, FileLimitsManager.hasReachedFreeLimit())
    }
}
