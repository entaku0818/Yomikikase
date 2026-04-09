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
    }

    // MARK: - speechFinished

    func test_初回読み上げ完了_completedCount1_でレビューが表示されること() async {
        UserDefaultsManager.shared.reviewRequestCount = 0
        UserDefaultsManager.shared.speechCompletedCount = 0

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

    func test_テキスト未入力かつ条件満たす場合にonAppearでレビューが表示されること() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 1
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false
        UserDefaultsManager.shared.lastReviewRequestDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())

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

    func test_テキスト入力済みの場合はonAppearで再表示されないこと() async {
        UserDefaultsManager.shared.reviewRequestCount = 1
        UserDefaultsManager.shared.speechCompletedCount = 1
        UserDefaultsManager.shared.hasAnsweredReviewPositively = false
        UserDefaultsManager.shared.lastReviewRequestDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        UserDefaultsManager.shared.installDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        // currentText が空でない場合
        let store = TestStore(initialState: Speeches.State(currentText: "読み上げるテキストが入力済み")) {
            Speeches()
        } withDependencies: {
            $0.analytics = .testValue
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { state in
            XCTAssertNil(state.alert)
        }
    }
}
