//
//  Setting.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/05/26.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var languageSetting: String?
        static let availableLanguages = [
            ("English", "en"),
            ("Japanese", "ja"),
            ("German", "de"),
            ("Spanish", "es"),
            ("Turkish", "tr"),
            ("French", "fr"),
            ("Vietnamese", "vi"),
            ("Thai", "th"),
            ("Korean", "ko"),
            ("Italian", "it")
        ]

        // 音声設定
        var selectedVoiceIdentifier: String?
        var showVoiceSettingView: Bool = false

        // 既存のプロパティ
        var title: String = ""
        var text: String = ""
        var speeches: [Speeches.Speech] = []
        var speechRate: Float = 0.5
        var speechPitch: Float = 1.0
        var showSuccess: Bool = false
        var showError: Bool = false
        var errorMessage: String = ""
        var isKeyboardFocused: Bool = false
        var successMessage: String = "保存しました"
        var showDeleteConfirmation: Bool = false
        var itemToDelete: UUID?
        var showSubscriptionView: Bool = false
        var showUserDictionaryView: Bool = false
    }

    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)

        enum View {
            case onAppear
            case setVoiceIdentifier(String?)
            case previewVoice(String)
            case navigateToVoiceSetting
            case setVoiceSettingNavigation(Bool)
            case setLanguage(String?)
            case setTitle(String)
            case setText(String)
            case setSpeechRate(Float)
            case setSpeechPitch(Float)
            case insert
            case fetchSpeeches
            case resetToDefault
            case dismissSuccess
            case dismissError
            case deleteSpeech(UUID)
            case setKeyboardFocus(Bool)
            case confirmDelete(UUID)
            case cancelDelete
            case executeDelete
            case navigateToSubscription
            case setSubscriptionNavigation(Bool)
            case navigateToUserDictionary
            case setUserDictionaryNavigation(Bool)
        }
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer
    @Dependency(\.analytics) var analytics

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .view(.navigateToVoiceSetting):
                state.showVoiceSettingView = true
                return .none

            case .view(.setVoiceSettingNavigation(let isPresented)):
                state.showVoiceSettingView = isPresented
                return .none

            case .view(.setVoiceIdentifier(let identifier)):
                state.selectedVoiceIdentifier = identifier
                UserDefaultsManager.shared.selectedVoiceIdentifier = identifier
                return .none

            case .view(.previewVoice(let text)):

                let utterance = AVSpeechUtterance(string: text)
                if let identifier = state.selectedVoiceIdentifier {
                    utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
                }
                utterance.rate = state.speechRate
                utterance.pitchMultiplier = state.speechPitch
                
                return .run { _ in
                    try? await speechSynthesizer.speak(utterance)
                }

            case .view(.setLanguage(let languageCode)):

                UserDefaultsManager.shared.languageSetting = languageCode
                if let code = languageCode, let languageName = State.availableLanguages.first(where: { $0.1 == code })?.0 {
                    state.languageSetting = languageName
                } else {
                    state.languageSetting = "English"
                }
                return .none

            case .view(.onAppear):
                analytics.logEvent("view_settings", nil)
                if let languageName = State.availableLanguages.first(where: { $0.1 == UserDefaultsManager.shared.languageSetting })?.0 {
                    state.languageSetting = languageName
                } else {
                    state.languageSetting = "English"
                }
                state.speechPitch = UserDefaultsManager.shared.speechPitch
                state.speechRate = UserDefaultsManager.shared.speechRate
                state.selectedVoiceIdentifier = UserDefaultsManager.shared.selectedVoiceIdentifier
                return .none

            case .view(.setTitle(let title)):
                state.title = title
                return .none

            case .view(.setText(let text)):
                state.text = text
                return .none

            case .view(.setSpeechRate(let rate)):

                state.speechRate = rate
                UserDefaultsManager.shared.speechRate = state.speechRate
                return .none

            case .view(.setSpeechPitch(let pitch)):

                state.speechPitch = pitch
                UserDefaultsManager.shared.speechPitch = state.speechPitch
                return .none

            case .view(.confirmDelete(let id)):
                guard let languageCode = UserDefaultsManager.shared.languageSetting else { return .none }
                let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
                
                guard let speechToDelete = state.speeches.first(where: { $0.id == id }) else { return .none }
                
                if speechToDelete.isDefault {
                    state.showError = true
                    state.errorMessage = "この言葉は事前登録されているため削除できません"
                    
                    return .run { send in
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        await send(.view(.dismissError))
                    }
                } else {
                    state.showDeleteConfirmation = true
                    state.itemToDelete = id
                    return .none
                }

            case .view(.cancelDelete):
                state.showDeleteConfirmation = false
                state.itemToDelete = nil
                return .none

            case .view(.executeDelete):
                guard let id = state.itemToDelete else { return .none }
                return .run { send in
                    await send(.view(.deleteSpeech(id)))
                }

            case .view(.navigateToSubscription):
                analytics.logEvent("subscription_view_opened", [
                    "source": "settings"
                ])
                state.showSubscriptionView = true
                return .none
                
            case .view(.setSubscriptionNavigation(let isPresented)):
                state.showSubscriptionView = isPresented
                return .none

            case .view(.navigateToUserDictionary):
                state.showUserDictionaryView = true
                return .none
                
            case .view(.setUserDictionaryNavigation(let isPresented)):
                state.showUserDictionaryView = isPresented
                return .none

            default:
                return .none
            }
        }
    }
}
