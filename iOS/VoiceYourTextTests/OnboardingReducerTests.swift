import XCTest
import ComposableArchitecture
import PDFKit
@testable import VoiceYourText

@MainActor
final class OnboardingReducerTests: XCTestCase {

    // MARK: - Step view analytics

    func test_stepViewAppeared_logsEventWithStep() async {
        var loggedEvent: String?
        var loggedParams: [String: Any]?
        let store = TestStore(initialState: OnboardingReducer.State()) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics.logEvent = { name, params in
                loggedEvent = name
                loggedParams = params
            }
            $0.analytics.setUserProperty = { _, _ in }
        }

        await store.send(.view(.stepViewAppeared(1))) { $0.viewedSteps = [1] }

        XCTAssertEqual(loggedEvent, "onboarding_step_view")
        XCTAssertEqual(loggedParams?["step"] as? Int, 1)
    }

    // MARK: - Step progression

    func test_nextTapped_incrementsStep() async {
        let store = TestStore(initialState: OnboardingReducer.State()) {
            OnboardingReducer()
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
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.view(.demoPlayTapped)) {
            $0.isSpeaking = true
            $0.hasStartedDemo = true
        }
    }

    func test_demoStopTapped_clearsSpeaking() async {
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1, isSpeaking: true)) {
            OnboardingReducer()
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
            OnboardingReducer()
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
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1, isSpeaking: true)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.speechCompleted(5.2)) {
            $0.isSpeaking = false
            $0.hasPlayed = true
        }
    }

    func test_speechCancelled_clearsSpeaking() async {
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1, isSpeaking: true)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics = .testValue
        }

        await store.send(.speechCancelled) {
            $0.isSpeaking = false
        }
    }

    // MARK: - Complete

    func test_completeTapped_logsEventAndSendsDelegate() async {
        var loggedEvent: String?
        var completedOnboardingSet: Bool?
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 2, hasPlayed: true)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics.logEvent = { name, _ in loggedEvent = name }
            $0.analytics.setUserProperty = { _, _ in }
            $0.userDefaults.setHasCompletedOnboarding = { completedOnboardingSet = $0 }
        }

        await store.send(.view(.completeTapped)) { $0.didComplete = true }
        await store.receive(.delegate(.completed))

        XCTAssertEqual(loggedEvent, "onboarding_completed")
        XCTAssertEqual(completedOnboardingSet, true)
    }

    // MARK: - PDF generation

    func test_samplePDFGenerated_storesData() async {
        let store = TestStore(initialState: OnboardingReducer.State()) {
            OnboardingReducer()
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
    func test_repeatedAppearanceAndPlaybackOnlyLogOnce() async {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics.logEvent = { name, _ in events.withValue { $0.append(name) } }
        }
        await store.send(.view(.stepViewAppeared(1))) { $0.viewedSteps = [1] }
        await store.send(.view(.stepViewAppeared(1)))
        await store.send(.view(.demoPlayTapped)) {
            $0.isSpeaking = true
            $0.hasStartedDemo = true
        }
        await store.send(.view(.demoPlayTapped))
        await store.send(.view(.demoStopTapped)) { $0.isSpeaking = false }
        await store.send(.speechCompleted(2)) // late callback after stop must not count
        await store.send(.view(.demoPlayTapped)) { $0.isSpeaking = true }
        await store.send(.speechCompleted(10)) {
            $0.isSpeaking = false
            $0.hasPlayed = true
        }
        await store.send(.speechCompleted(10))
        XCTAssertEqual(events.value, ["onboarding_step_view", "onboarding_demo_played", "onboarding_demo_completed"])
    }

    func test_skipWhileSpeakingIgnoresLateCompletionAndRepeatedSkip() async {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 1, isSpeaking: true)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics.logEvent = { name, _ in events.withValue { $0.append(name) } }
        }
        await store.send(.view(.skipTapped)) {
            $0.currentStep = 2
            $0.isSpeaking = false
        }
        await store.send(.speechCompleted(10))
        await store.send(.view(.skipTapped))
        await store.send(.view(.nextTapped))
        XCTAssertEqual(events.value, ["onboarding_skipped"])
    }

    func test_completionIsIdempotentWithoutDemo() async {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: OnboardingReducer.State(currentStep: 2)) {
            OnboardingReducer()
        } withDependencies: {
            $0.analytics.logEvent = { name, params in
                events.withValue { $0.append(name) }
                XCTAssertEqual(params?["completed_demo"] as? Int, 0)
            }
            $0.userDefaults.setHasCompletedOnboarding = { _ in }
        }
        await store.send(.view(.completeTapped)) { $0.didComplete = true }
        await store.receive(.delegate(.completed))
        await store.send(.view(.completeTapped))
        XCTAssertEqual(events.value, ["onboarding_completed"])
    }

    func test_sampleUsesMatchingTextVoiceAndFallback() {
        let japanese = OnboardingSample(languageCode: "ja-JP")
        let english = OnboardingSample(languageCode: "en-GB")
        XCTAssertEqual(japanese.voiceLanguage, "ja-JP")
        XCTAssertEqual(english.voiceLanguage, "en-US")
        XCTAssertEqual(OnboardingSample(languageCode: "fr"), english)
        XCTAssertTrue(japanese.text.contains("資料"))
        XCTAssertTrue(english.text.contains("document"))
        for sample in [japanese, english] {
            let document = PDFDocument(data: makeSamplePDFData(sample: sample))
            XCTAssertNotNil(document)
            XCTAssertTrue(document?.string?.contains(sample.title) == true)
        }
    }

}
