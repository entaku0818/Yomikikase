import XCTest
import ComposableArchitecture
import PDFKit
@testable import VoiceYourText

@MainActor
final class OnboardingReducerTests: XCTestCase {

    // MARK: - Step progression

    func test_nextTapped_incrementsStep() async {
        let store = TestStore(initialState: OnboardingReducer.State()) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.view(.nextTapped)) {
            $0.currentStep = 1
            $0.isSpeaking = false
        }
        await store.send(.view(.nextTapped)) {
            $0.currentStep = 2
        }
    }

    // MARK: - Demo play/stop

    func test_demoPlayTapped_setsSpeaking() async {
        let store = TestStore(initialState: OnboardingReducer.State()) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.view(.demoPlayTapped)) {
            $0.isSpeaking = true
        }
    }

    func test_demoStopTapped_clearsSpeaking() async {
        let store = TestStore(initialState: OnboardingReducer.State(isSpeaking: true)) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.view(.demoStopTapped)) {
            $0.isSpeaking = false
        }
    }

    // MARK: - Skip

    func test_skipTapped_logsEventAndAdvances() async {
        var loggedEvent: String?
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1)) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics.logEvent = { name, _ in loggedEvent = name }
            $0.analytics.setUserProperty = { _, _ in }
        }

        await store.send(.view(.skipTapped)) {
            $0.currentStep = 2
            $0.isSpeaking = false
        }

        XCTAssertEqual(loggedEvent, "onboarding_skipped")
    }

    // MARK: - Speech callbacks

    func test_speechCompleted_setsHasPlayedAndClearsSpeaking() async {
        let store = TestStore(initialState: OnboardingReducer.State(isSpeaking: true)) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.speechCompleted(5.2)) {
            $0.isSpeaking = false
            $0.hasPlayed = true
        }
    }

    func test_speechCancelled_clearsSpeaking() async {
        let store = TestStore(initialState: OnboardingReducer.State(isSpeaking: true)) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.speechCancelled) {
            $0.isSpeaking = false
        }
    }

    // MARK: - Complete

    func test_completeTapped_logsEventAndCallsOnComplete() async {
        var completeCalled = false
        var loggedEvent: String?
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 2, hasPlayed: true)) {
            OnboardingReducer(onComplete: { completeCalled = true })
        } withDependencies: {
            $0.analytics.logEvent = { name, _ in loggedEvent = name }
            $0.analytics.setUserProperty = { _, _ in }
        }

        await store.send(.view(.completeTapped))
        await store.finish()

        XCTAssertEqual(loggedEvent, "onboarding_completed")
        XCTAssertTrue(completeCalled)
    }

    // MARK: - PDF generation

    func test_samplePDFGenerated_storesData() async {
        let store = TestStore(initialState: OnboardingReducer.State()) {
            OnboardingReducer(onComplete: {})
        } withDependencies: {
            $0.analytics = .testValue
        }
        let data = Data([0x25, 0x50, 0x44, 0x46])

        await store.send(.samplePDFGenerated(data)) {
            $0.samplePDFData = data
        }
    }

    func test_makeSamplePDFData_returnsValidPDF() {
        let data = makeSamplePDFData()
        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(PDFDocument(data: data))
    }
}
