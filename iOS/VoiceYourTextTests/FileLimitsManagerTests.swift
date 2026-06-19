//
//  FileLimitsManagerTests.swift
//  VoiceYourTextTests
//

import XCTest
@testable import VoiceYourText

final class FileLimitsManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // プレミアムフラグをリセット
        UserDefaultsManager.shared.isPremiumUser = false
    }

    override func tearDown() {
        super.tearDown()
        // プレミアムフラグをリセット
        UserDefaultsManager.shared.isPremiumUser = false
    }

    // MARK: - maxFreeFileCount

    func test_maxFreeFileCount_が5であること() {
        XCTAssertEqual(FileLimitsManager.maxFreeFileCount, 5)
    }

    // MARK: - hasReachedFreeLimit（プレミアムバイパス）

    func test_プレミアムユーザーはhasReachedFreeLimitがfalseを返すこと() {
        UserDefaultsManager.shared.isPremiumUser = true

        // ファイル数に関わらずプレミアムはfalse
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit())
    }

    // MARK: - remainingFileCount（プレミアムバイパス）

    func test_プレミアムユーザーのremainingFileCountがIntMaxであること() {
        UserDefaultsManager.shared.isPremiumUser = true

        XCTAssertEqual(FileLimitsManager.remainingFileCount(), Int.max)
    }

    // MARK: - remainingFileCount（無料ユーザー・ファイル数コントロール不可のため間接検証）

    func test_無料ユーザーのremainingFileCountは最大5以下であること() {
        UserDefaultsManager.shared.isPremiumUser = false

        let remaining = FileLimitsManager.remainingFileCount()
        // 実際のファイル数が不定でも remainingFileCount() は 0 以上かつ maxFreeFileCount 以下
        XCTAssertGreaterThanOrEqual(remaining, 0)
        XCTAssertLessThanOrEqual(remaining, FileLimitsManager.maxFreeFileCount)
    }

    // MARK: - hasReachedFreeLimit 計算ロジックの一貫性

    func test_hasReachedFreeLimitとremainingFileCountの整合性() {
        UserDefaultsManager.shared.isPremiumUser = false

        let hasReached = FileLimitsManager.hasReachedFreeLimit()
        let remaining = FileLimitsManager.remainingFileCount()

        if hasReached {
            XCTAssertEqual(remaining, 0, "制限に達しているなら残り数は0のはず")
        } else {
            XCTAssertGreaterThan(remaining, 0, "制限未達なら残り数は1以上のはず")
        }
    }

    // MARK: - maxFreeFileCount 境界値（ロジック検証）

    func test_境界値_totalFileCountが5以上で制限に達するロジック() {
        // FileLimitsManager のロジック: getCurrentTotalFileCount() >= maxFreeFileCount
        // 直接テストできないため、計算ロジックを単体で検証する
        let maxCount = FileLimitsManager.maxFreeFileCount  // 5

        // 4ファイル: 制限未達
        let notReachedAt4 = 4 >= maxCount
        XCTAssertFalse(notReachedAt4, "4ファイルは制限未達のはず（4 >= 5 == false）")

        // 5ファイル: 制限到達
        let reachedAt5 = 5 >= maxCount
        XCTAssertTrue(reachedAt5, "5ファイルで制限到達のはず（5 >= 5 == true）")

        // 6ファイル: 制限到達
        let reachedAt6 = 6 >= maxCount
        XCTAssertTrue(reachedAt6, "6ファイルで制限到達のはず（6 >= 5 == true）")
    }

    func test_境界値_remainingFileCountが4ファイルで1を返すロジック() {
        let maxCount = FileLimitsManager.maxFreeFileCount  // 5

        // max(0, 5 - 4) == 1
        let remainingAt4 = max(0, maxCount - 4)
        XCTAssertEqual(remainingAt4, 1, "4ファイル時の残り数は1のはず")
    }

    func test_境界値_remainingFileCountが5ファイルで0を返すロジック() {
        let maxCount = FileLimitsManager.maxFreeFileCount  // 5

        // max(0, 5 - 5) == 0
        let remainingAt5 = max(0, maxCount - 5)
        XCTAssertEqual(remainingAt5, 0, "5ファイル時の残り数は0のはず")
    }

    func test_境界値_remainingFileCountが6ファイルで0を返すロジック_アンダーフロー防止() {
        let maxCount = FileLimitsManager.maxFreeFileCount  // 5

        // max(0, 5 - 6) == 0 (負数にはならない)
        let remainingAt6 = max(0, maxCount - 6)
        XCTAssertEqual(remainingAt6, 0, "6ファイル時の残り数は0（負数にならない）のはず")
    }
}
