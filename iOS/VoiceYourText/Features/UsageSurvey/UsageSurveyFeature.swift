import ComposableArchitecture
import Foundation

@Reducer
struct UsageSurveyFeature {
    @ObservableState
    struct State: Equatable {
        var content = ""
        var situation = ""
        var suggestions = ""
        var isSubmitting = false
        var submitted = false
        var failed = false

        var message: String {
            "[Usage Survey v1]\nContent: \(content.trimmingCharacters(in: .whitespacesAndNewlines))\nSituation: \(situation.trimmingCharacters(in: .whitespacesAndNewlines))\nSuggestions: \(suggestions.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        // The existing feedback endpoint limits message.length to 2,000 UTF-16 units.
        var isTooLong: Bool { message.utf16.count > 2_000 }
        var canSubmit: Bool {
            !isSubmitting && !submitted && !isTooLong && [content, situation, suggestions].contains {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case view(View)
        case submissionFinished(Bool)
        enum View { case submit }
    }

    @Dependency(\.feedbackClient) var feedbackClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(.submit):
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.failed = false
                let message = state.message
                return .run { send in
                    do {
                        try await feedbackClient.submit(message, "")
                        await send(.submissionFinished(true))
                    } catch {
                        await send(.submissionFinished(false))
                    }
                }
            case let .submissionFinished(success):
                state.isSubmitting = false
                state.submitted = success
                state.failed = !success
                return .none
            case .binding:
                return .none
            }
        }
    }
}
