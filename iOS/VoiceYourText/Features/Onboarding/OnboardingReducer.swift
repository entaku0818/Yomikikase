import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingReducer {
    @ObservableState
    struct State: Equatable {
        var currentStep: Int = 0
        var samplePDFData: Data?
        var isSpeaking: Bool = false
        var hasPlayed: Bool = false
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
                analytics.logEvent("onboarding_step_view", ["step": step])
                return .none

            case .view(.demoPlayTapped):
                state.isSpeaking = true
                analytics.logEvent("onboarding_demo_played", ["demo_type": "pdf"])
                return .none

            case .view(.demoStopTapped):
                state.isSpeaking = false
                return .none

            case .view(.nextTapped):
                advanceStep(state: &state)
                return .none

            case .view(.skipTapped):
                analytics.logEvent("onboarding_skipped", ["step": state.currentStep])
                advanceStep(state: &state)
                return .none

            case .view(.completeTapped):
                analytics.logEvent("onboarding_completed", ["completed_demo": state.hasPlayed ? 1 : 0])
                userDefaults.setHasCompletedOnboarding(true)
                return .send(.delegate(.completed))

            case let .samplePDFGenerated(data):
                state.samplePDFData = data
                return .none

            case let .speechCompleted(duration):
                state.isSpeaking = false
                state.hasPlayed = true
                analytics.logEvent("onboarding_demo_completed", ["listen_duration": duration])
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
        state.isSpeaking = false
        state.currentStep += 1
    }
}
