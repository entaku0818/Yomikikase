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

    func test_プレミアムユーザーはファイル数に関わらずhasReachedFreeLimitがfalseを返すこと() {
        // ファイル数が制限を超えていてもプレミアムなら false
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 100, isPremiumUser: true))
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 5, isPremiumUser: true))
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 0, isPremiumUser: true))
    }

    // MARK: - hasReachedFreeLimit（無料ユーザー・境界値を実装で検証）

    func test_無料ユーザーは4ファイルで制限未達であること() {
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 4, isPremiumUser: false),
                       "4ファイルは maxFreeFileCount(5) 未満のため制限未達のはず")
    }

    func test_無料ユーザーは5ファイルで制限到達であること() {
        XCTAssertTrue(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 5, isPremiumUser: false),
                      "5ファイルで maxFreeFileCount に到達するため制限到達のはず")
    }

    func test_無料ユーザーは6ファイルで制限到達であること() {
        XCTAssertTrue(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 6, isPremiumUser: false),
                      "6ファイルは制限超過のため制限到達のはず")
    }

    func test_無料ユーザーは0ファイルで制限未達であること() {
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit(totalFileCount: 0, isPremiumUser: false))
    }

    // MARK: - remainingFileCount（プレミアムバイパス）

    func test_プレミアムユーザーのremainingFileCountがIntMaxであること() {
        XCTAssertEqual(FileLimitsManager.remainingFileCount(totalFileCount: 0, isPremiumUser: true), Int.max)
        XCTAssertEqual(FileLimitsManager.remainingFileCount(totalFileCount: 100, isPremiumUser: true), Int.max)
    }

    // MARK: - remainingFileCount（無料ユーザー・境界値を実装で検証）

    func test_無料ユーザーの残り数_0ファイルで5を返すこと() {
        XCTAssertEqual(FileLimitsManager.remainingFileCount(totalFileCount: 0, isPremiumUser: false), 5)
    }

    func test_無料ユーザーの残り数_4ファイルで1を返すこと() {
        XCTAssertEqual(FileLimitsManager.remainingFileCount(totalFileCount: 4, isPremiumUser: false), 1)
    }

    func test_無料ユーザーの残り数_5ファイルで0を返すこと() {
        XCTAssertEqual(FileLimitsManager.remainingFileCount(totalFileCount: 5, isPremiumUser: false), 0)
    }

    func test_無料ユーザーの残り数_6ファイルで0を返すこと_アンダーフロー防止() {
        XCTAssertEqual(FileLimitsManager.remainingFileCount(totalFileCount: 6, isPremiumUser: false), 0,
                       "制限超過でも負数にならず0を返すはず")
    }

    // MARK: - hasReachedFreeLimit と remainingFileCount の整合性（無料ユーザー・全境界）

    func test_無料ユーザーの2メソッドの整合性が全境界で保たれること() {
        for total in 0...10 {
            let hasReached = FileLimitsManager.hasReachedFreeLimit(totalFileCount: total, isPremiumUser: false)
            let remaining = FileLimitsManager.remainingFileCount(totalFileCount: total, isPremiumUser: false)
            if hasReached {
                XCTAssertEqual(remaining, 0, "制限到達（total=\(total)）なら残り数は0のはず")
            } else {
                XCTAssertGreaterThan(remaining, 0, "制限未達（total=\(total)）なら残り数は1以上のはず")
            }
        }
    }

    // MARK: - UserDefaults 経由の実インスタンスメソッド（プレミアムバイパス）

    func test_プレミアムユーザーは引数なしhasReachedFreeLimitがfalseを返すこと() {
        UserDefaultsManager.shared.isPremiumUser = true
        XCTAssertFalse(FileLimitsManager.hasReachedFreeLimit())
    }

    func test_プレミアムユーザーは引数なしremainingFileCountがIntMaxを返すこと() {
        UserDefaultsManager.shared.isPremiumUser = true
        XCTAssertEqual(FileLimitsManager.remainingFileCount(), Int.max)
    }
}
