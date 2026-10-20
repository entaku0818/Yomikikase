import XCTest
import ComposableArchitecture
@testable import VoiceYourText

@MainActor
final class UsageSurveyTests: XCTestCase {
    func testOptionalAnswersAndServerLimit() {
        var state = UsageSurveyFeature.State()
        XCTAssertFalse(state.canSubmit)
        state.content = " \n "
        XCTAssertFalse(state.canSubmit)
        state.situation = "通勤中"
        XCTAssertTrue(state.canSubmit)
        state.situation = String(repeating: "😀", count: 1_000)
        XCTAssertTrue(state.isTooLong)
        XCTAssertFalse(state.canSubmit)
    }

    func testSendOnlyAnsweredQuestionWithoutEmail() async {
        let store = TestStore(initialState: UsageSurveyFeature.State(situation: " 通勤中 ")) {
            UsageSurveyFeature()
        } withDependencies: {
            $0.feedbackClient.submit = { message, email in
                XCTAssertEqual(message, "[Usage Survey v1]\nContent: \nSituation: 通勤中\nSuggestions: ")
                XCTAssertEqual(email, "")
            }
        }
        await store.send(.view(.submit)) { $0.isSubmitting = true }
        await store.receive(\.submissionFinished, true) {
            $0.isSubmitting = false
            $0.submitted = true
        }
        XCTAssertFalse(store.state.canSubmit)
    }

    func testFailureKeepsAnswersAndAllowsRetry() async {
        let store = TestStore(initialState: UsageSurveyFeature.State(content: "小説")) {
            UsageSurveyFeature()
        } withDependencies: {
            $0.feedbackClient.submit = { _, _ in throw URLError(.notConnectedToInternet) }
        }
        await store.send(.view(.submit)) { $0.isSubmitting = true }
        await store.receive(\.submissionFinished, false) {
            $0.isSubmitting = false
            $0.failed = true
        }
        XCTAssertEqual(store.state.content, "小説")
        XCTAssertTrue(store.state.canSubmit)
        await store.send(.view(.submit)) {
            $0.isSubmitting = true
            $0.failed = false
        }
        await store.receive(\.submissionFinished, false) {
            $0.isSubmitting = false
            $0.failed = true
        }
    }

    func testEmptyAndDuplicateSubmissionsAreIgnored() async {
        let store = TestStore(initialState: UsageSurveyFeature.State()) { UsageSurveyFeature() }
        await store.send(.view(.submit))
        let pending = TestStore(initialState: UsageSurveyFeature.State(content: "本", isSubmitting: true)) {
            UsageSurveyFeature()
        }
        await pending.send(.view(.submit))
    }
}
