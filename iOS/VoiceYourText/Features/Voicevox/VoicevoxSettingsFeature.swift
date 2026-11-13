import Foundation
import ComposableArchitecture

/// 設定画面の「キャラ音声（VOICEVOX）」セクション。
@Reducer
struct VoicevoxSettingsFeature {
    @ObservableState
    struct State: Equatable {
        var isEnabled = false
        var selectedSpeakerId = VoicevoxCatalog.unselectedSpeakerId
        var usage: VoicevoxUsage?
        var isUsageUnavailable = false
        var previewingSpeakerId: Int?
        var showPaywall = false
        var catalog: VoicevoxCatalog?
        var isCatalogLoading = false
        var isCatalogUnavailable = false
        var voices: [VoicevoxVoice] { catalog?.voices ?? [] }
    }

    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case catalogLoaded(VoicevoxCatalog)
        case catalogFailed
        case usageLoaded(VoicevoxUsage)
        case usageFailed
        case previewFinished
        case previewQuotaExceeded(VoicevoxUsage)

        enum View {
            case onAppear
            case loadCatalog
            case enabledChanged(Bool)
            case voiceTapped(Int)
            case upgradeTapped
        }
    }

    private enum CancelID { case preview, catalog }

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
                state.catalog = voicevox.cachedCatalog()
                // オフのまま通常画面を表示しただけではサーバーを起こさない。
                state.isCatalogLoading = state.isEnabled
                return state.isEnabled ? loadCatalog(includeUsage: true) : .none

            case .view(.loadCatalog):
                state.isCatalogLoading = true
                state.isCatalogUnavailable = false
                return loadCatalog(includeUsage: state.isEnabled)

            case let .catalogLoaded(catalog):
                state.catalog = catalog
                state.isCatalogLoading = false
                state.isCatalogUnavailable = false
                let selected = catalog.selection(for: state.selectedSpeakerId) ?? VoicevoxCatalog.unselectedSpeakerId
                if selected != state.selectedSpeakerId {
                    state.selectedSpeakerId = selected
                    settings.setSpeakerId(selected)
                }
                return .none

            case .catalogFailed:
                state.catalog = nil
                state.isCatalogLoading = false
                state.isCatalogUnavailable = true
                return .none

            case let .view(.enabledChanged(enabled)):
                state.isEnabled = enabled
                settings.setEnabled(enabled)
                analytics.logEvent("voicevox_toggle", ["enabled": enabled ? "true" : "false"])
                state.isCatalogLoading = enabled
                return enabled ? loadCatalog(includeUsage: true) : .cancel(id: CancelID.catalog)

            case let .view(.voiceTapped(speakerId)):
                guard !state.isCatalogLoading, !state.isCatalogUnavailable,
                      let voice = state.catalog?.voice(for: speakerId) else { return .none }
                // 再生画面の声の一覧からキャラを選んだときは、キャラ音声もオンにする
                if !state.isEnabled {
                    state.isEnabled = true
                    settings.setEnabled(true)
                }
                state.selectedSpeakerId = speakerId
                settings.setSpeakerId(speakerId)
                state.previewingSpeakerId = speakerId
                let text = Self.previewText(for: voice)
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

    private func loadCatalog(includeUsage: Bool) -> Effect<Action> {
        .run { send in
            do {
                let catalog = try await voicevox.catalog().validated()
                try Task.checkCancellation()
                await send(.catalogLoaded(catalog))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await send(.catalogFailed)
            }
            if includeUsage {
                do { await send(.usageLoaded(try await voicevox.quota())) }
                catch { if !Task.isCancelled { await send(.usageFailed) } }
            }
        }
        .cancellable(id: CancelID.catalog, cancelInFlight: true)
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
