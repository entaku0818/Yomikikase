import Foundation
import ComposableArchitecture

/// 設定画面の「キャラ音声（VOICEVOX）」セクション。
@Reducer
struct VoicevoxSettingsFeature {
    @ObservableState
    struct State: Equatable {
        var isEnabled = false
        var selectedSpeakerId = VoicevoxCatalog.defaultSpeakerId
        var usage: VoicevoxUsage?
        var isUsageUnavailable = false
        var previewingSpeakerId: Int?
        var showPaywall = false
        var voices = VoicevoxCatalog.voices
    }

    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case usageLoaded(VoicevoxUsage)
        case usageFailed
        case previewFinished
        case previewQuotaExceeded(VoicevoxUsage)

        enum View {
            case onAppear
            case enabledChanged(Bool)
            case voiceTapped(Int)
            case upgradeTapped
        }
    }

    private enum CancelID { case preview }

    @Dependency(\.voicevox) var voicevox
    @Dependency(\.voicevoxSettings) var settings
    @Dependency(\.voicevoxPlayer) var player
    @Dependency(\.analytics) var analytics

    static func previewText(for voice: VoicevoxVoice) -> String {
        "こんにちは、\(voice.character)です。この声で読み上げます。"
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .view(.onAppear):
                state.isEnabled = settings.isEnabled()
                state.selectedSpeakerId = settings.speakerId()
                return loadUsage()

            case let .view(.enabledChanged(enabled)):
                state.isEnabled = enabled
                settings.setEnabled(enabled)
                analytics.logEvent("voicevox_toggle", ["enabled": enabled ? "true" : "false"])
                return enabled ? loadUsage() : .none

            case let .view(.voiceTapped(speakerId)):
                state.selectedSpeakerId = speakerId
                settings.setSpeakerId(speakerId)
                state.previewingSpeakerId = speakerId
                let text = Self.previewText(for: VoicevoxCatalog.voice(for: speakerId))
                return .run { send in
                    await player.stop()
                    for await event in await player.play(text, speakerId, 1.0) {
                        if case let .quotaExceeded(usage, _) = event {
                            await send(.previewQuotaExceeded(usage))
                            return
                        }
                    }
                    await send(.previewFinished)
                }
                .cancellable(id: CancelID.preview, cancelInFlight: true)

            case .view(.upgradeTapped):
                state.showPaywall = true
                return .none

            case let .usageLoaded(usage):
                state.usage = usage
                state.isUsageUnavailable = false
                return .none

            case .usageFailed:
                state.isUsageUnavailable = true
                return .none

            case .previewFinished:
                state.previewingSpeakerId = nil
                return loadUsage()

            case let .previewQuotaExceeded(usage):
                state.previewingSpeakerId = nil
                state.usage = usage
                if !usage.isPremium {
                    state.showPaywall = true
                }
                return .none
            }
        }
    }

    private func loadUsage() -> Effect<Action> {
        .run { send in
            do {
                await send(.usageLoaded(try await voicevox.quota()))
            } catch {
                await send(.usageFailed)
            }
        }
    }
}
