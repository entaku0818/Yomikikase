//
//  DeletedItemsFeature.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/28.
//

import ComposableArchitecture
import Foundation

@Reducer
struct DeletedItemsFeature {
    @ObservableState
    struct State: Equatable {
        var deletedFiles: IdentifiedArrayOf<DeletedFileItem> = []
        var selectedFile: DeletedFileItem?
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Equatable {
        case onAppear
        case filesLoaded([DeletedFileItem])
        case restoreTapped(DeletedFileItem)
        case deleteTapped(DeletedFileItem)
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case confirmRestore
            case confirmDelete
            case cancel
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let files = loadDeletedFiles()
                    await send(.filesLoaded(files))
                }

            case let .filesLoaded(files):
                state.deletedFiles = IdentifiedArrayOf(uniqueElements: files)
                return .none

            case let .restoreTapped(file):
                state.selectedFile = file
                state.alert = AlertState {
                    TextState("復元しますか？")
                } actions: {
                    ButtonState(action: .confirmRestore) {
                        TextState("復元")
                    }
                    ButtonState(role: .cancel, action: .cancel) {
                        TextState("キャンセル")
                    }
                } message: {
                    TextState("「\(file.title)」をマイファイルに戻します")
                }
                return .none

            case let .deleteTapped(file):
                state.selectedFile = file
                state.alert = AlertState {
                    TextState("完全に削除しますか？")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("削除")
                    }
                    ButtonState(role: .cancel, action: .cancel) {
                        TextState("キャンセル")
                    }
                } message: {
                    TextState("「\(file.title)」を完全に削除します。この操作は取り消せません。")
                }
                return .none

            case .alert(.presented(.confirmRestore)):
                guard let file = state.selectedFile else { return .none }
                SpeechTextRepository.shared.restore(id: file.id)
                state.selectedFile = nil
                return .run { send in
                    let files = loadDeletedFiles()
                    await send(.filesLoaded(files))
                }

            case .alert(.presented(.confirmDelete)):
                guard let file = state.selectedFile else { return .none }
                SpeechTextRepository.shared.permanentlyDelete(id: file.id)
                state.selectedFile = nil
                return .run { send in
                    let files = loadDeletedFiles()
                    await send(.filesLoaded(files))
                }

            case .alert(.presented(.cancel)):
                state.selectedFile = nil
                return .none

            case .alert(.dismiss):
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Helper Functions

private func loadDeletedFiles() -> [DeletedFileItem] {
    let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
    let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
    let speeches = SpeechTextRepository.shared.fetchDeletedSpeechText(language: languageSetting)

    return speeches.map { speech in
        DeletedFileItem(
            id: speech.id,
            title: speech.title,
            deletedAt: speech.deletedAt ?? Date(),
            daysRemaining: daysUntilPermanentDeletion(speech.deletedAt)
        )
    }
}

private func daysUntilPermanentDeletion(_ deletedAt: Date?) -> Int {
    guard let deletedAt = deletedAt else { return 7 }
    let expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: deletedAt) ?? Date()
    let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    return max(0, days)
}

// MARK: - DeletedFileItem Model

struct DeletedFileItem: Equatable, Identifiable {
    let id: UUID
    let title: String
    let deletedAt: Date
    let daysRemaining: Int
}
