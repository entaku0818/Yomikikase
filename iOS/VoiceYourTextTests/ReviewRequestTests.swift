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

    // MARK: - 2回目起動

    func test_2回目起動でレビューが表示されること() async {
        UserDefaultsManager.shared.appLaunchCount = 1  // 次で2回目
        UserDefaultsManager.shared.reviewRequestCount = 0
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let store = TestStore(initialState: Speeches.State(currentText: "")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
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
        XCTAssertEqual(UserDefaultsManager.shared.appLaunchCount, 2)
    }

    func test_3回目以降の起動ではレビューが表示されないこと() async {
        UserDefaultsManager.shared.appLaunchCount = 2  // 次で3回目
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false
        UserDefaultsManager.shared.lastReviewRequestDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let store = TestStore(initialState: Speeches.State(currentText: "")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
            XCTAssertNil(state.alert)
        }
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

    // MARK: - onAppear 再表示

    func test_条件満たす場合にonAppearでレビューが表示されること() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 1
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false
        UserDefaultsManager.shared.lastReviewRequestDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        let store = TestStore(initialState: Speeches.State(currentText: "読み上げるテキスト")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
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

    func test_hasAnsweredReviewPositivelyがtrueの場合は再表示されないこと() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 1
        UserDefaultsManager.shared.hasAnsweredReviewPositively = true
        UserDefaultsManager.shared.lastReviewRequestDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        let store = TestStore(initialState: Speeches.State(currentText: "")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
            XCTAssertNil(state.alert)
        }
    }

    func test_lastReviewRequestDateが3日以内の場合は再表示されないこと() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 1
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false
        UserDefaultsManager.shared.lastReviewRequestDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        let store = TestStore(initialState: Speeches.State(currentText: "")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
            XCTAssertNil(state.alert)
        }
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
