import ComposableArchitecture
import Foundation

/// The sample has matching text and speech. Other UI languages use the English sample.
struct OnboardingSample: Equatable, Sendable {
    let languageCode: String
    var voiceLanguage: String { languageCode == "ja" ? "ja-JP" : "en-US" }
    var title: String { languageCode == "ja" ? "声で読むサンプル" : "A sample to listen to" }
    var text: String {
        languageCode == "ja"
            ? "読みたい文章を、聴ける時間に。資料や本を開いて再生すれば、通勤中や料理中にも聴けます。"
            : "Turn reading time into listening time. Open a document or book and listen on your commute or while cooking."
    }
    init(languageCode: String) {
        self.languageCode = Locale(identifier: languageCode).language.languageCode?.identifier == "ja" ? "ja" : "en"
    }
    static var current: Self { Self(languageCode: Bundle.main.preferredLocalizations.first ?? "en") }
}

@Reducer
struct OnboardingReducer {
    @ObservableState
    struct State: Equatable {
        var currentStep: Int = 0
        var samplePDFData: Data?
        var isSpeaking: Bool = false
        var hasPlayed: Bool = false
        var viewedSteps: Set<Int> = []
        var hasStartedDemo = false
        var didComplete = false
        var sampleLanguage = OnboardingSample.current.languageCode
    }

    enum Action: ViewAction, Equatable {
        case view(View)
        case delegate(Delegate)
        case samplePDFGenerated(Data)
        case speechCompleted(Double)
        case speechCancelled

        enum View: Equatable {
            case stepViewAppeared(Int)
            case demoPlayTapped
            case demoStopTapped
            case nextTapped
            case skipTapped
            case completeTapped
        }

        enum Delegate: Equatable {
            case completed
        }
    }

    @Dependency(\.analytics) var analytics
    @Dependency(\.userDefaults) var userDefaults

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(.stepViewAppeared(step)):
                guard (0...2).contains(step), !state.didComplete,
                      state.viewedSteps.insert(step).inserted else { return .none }
                analytics.logEvent("onboarding_step_view", ["step": step])
                return .none

            case .view(.demoPlayTapped):
                guard state.currentStep == 1, !state.isSpeaking, !state.didComplete else { return .none }
                state.isSpeaking = true
                if !state.hasStartedDemo {
                    state.hasStartedDemo = true
                    analytics.logEvent("onboarding_demo_played", [
                        "demo_type": "pdf", "sample_language": state.sampleLanguage
                    ])
                }
                return .none

            case .view(.demoStopTapped):
                state.isSpeaking = false
                return .none

            case .view(.nextTapped):
                advanceStep(state: &state)
                return .none

            case .view(.skipTapped):
                guard state.currentStep < 2, !state.didComplete else { return .none }
                analytics.logEvent("onboarding_skipped", ["step": state.currentStep])
                advanceStep(state: &state)
                return .none

            case .view(.completeTapped):
                guard state.currentStep == 2, !state.didComplete else { return .none }
                state.didComplete = true
                analytics.logEvent("onboarding_completed", ["completed_demo": state.hasPlayed ? 1 : 0])
                userDefaults.setHasCompletedOnboarding(true)
                return .send(.delegate(.completed))

            case let .samplePDFGenerated(data):
                state.samplePDFData = data
                return .none

            case let .speechCompleted(duration):
                guard state.currentStep == 1, state.isSpeaking else { return .none }
                state.isSpeaking = false
                guard !state.hasPlayed else { return .none }
                state.hasPlayed = true
                analytics.logEvent("onboarding_demo_completed", [
                    "listen_duration": duration, "sample_language": state.sampleLanguage
                ])
                return .none

            case .speechCancelled:
                state.isSpeaking = false
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func advanceStep(state: inout State) {
        guard state.currentStep < 2, !state.didComplete else { return }
        state.isSpeaking = false
        state.currentStep += 1
    }
}
