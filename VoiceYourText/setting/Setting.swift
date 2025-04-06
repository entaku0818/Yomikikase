//
//  Setting.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/05/26.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

struct SettingsReducer: Reducer {
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

        var title: String = ""
        var text: String = ""
        var speeches: [Speeches.Speech] = []
        var speechRate: Float = 0.5
        var speechPitch: Float = 1.0
        var showSuccess: Bool = false
        var showError: Bool = false
        var errorMessage: String = ""
        var isKeyboardFocused: Bool = false
    }

    enum Action: Equatable, Sendable {
        case setLanguage(String?)
        case onAppear
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
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setLanguage(let languageCode):
                UserDefaultsManager.shared.languageSetting = languageCode
                if let code = languageCode, let languageName = SettingsReducer.State.availableLanguages.first(where: { $0.1 == code })?.0 {
                    state.languageSetting = languageName
                } else {
                    state.languageSetting = "English"
                }
                return .none

            case .onAppear:
                if let languageName = SettingsReducer.State.availableLanguages.first(where: { $0.1 == UserDefaultsManager.shared.languageSetting })?.0 {
                    state.languageSetting = languageName
                } else {
                    state.languageSetting = "English"
                }
                state.speechPitch = UserDefaultsManager.shared.speechPitch
                state.speechRate = UserDefaultsManager.shared.speechRate

                return .none

            case .setTitle(let title):
                state.title = title
                return .none

            case .setText(let text):
                state.text = text
                return .none
            case .setSpeechRate(let rate):
                state.speechRate = rate
                UserDefaultsManager.shared.speechRate = state.speechRate

                return .none
            case .setSpeechPitch(let pitch):
                state.speechPitch = pitch
                UserDefaultsManager.shared.speechPitch = state.speechPitch
                return .none

            case .insert:
                guard let languageCode = UserDefaultsManager.shared.languageSetting else { return .none }
                
                // テキストが空の場合はエラーメッセージを表示
                if state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.showError = true
                    state.errorMessage = "テキストを入力してください"
                    
                    return .run { send in
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
                        await send(.dismissError)
                    }
                }
                
                let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
                SpeechTextRepository.shared.insert(title: state.text, text: state.text, languageSetting: languageSetting)

                state.title = ""
                state.text = ""
                state.showSuccess = true
                state.isKeyboardFocused = false
                
                // 自動的に成功表示を隠す
                return .run { send in
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
                    await send(.dismissSuccess)
                    await send(.fetchSpeeches) // 保存後にリストを更新
                }
                
            case .fetchSpeeches:
                guard let languageCode = UserDefaultsManager.shared.languageSetting else { return .none }
                let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
                state.speeches = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)
                return .none
            case .resetToDefault:
                state.speechRate = 0.5
                state.speechPitch = 1.0
                  UserDefaultsManager.shared.speechRate = state.speechRate
                  UserDefaultsManager.shared.speechPitch = state.speechPitch
                  return .none
            case .dismissSuccess:
                state.showSuccess = false
                return .none
                
            case .dismissError:
                state.showError = false
                return .none
                
            case .deleteSpeech(let id):
                guard let languageCode = UserDefaultsManager.shared.languageSetting else { return .none }
                let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
                
                // デフォルトの挨拶は削除できないようにする
                let defaultSpeeches = SpeechTextRepository.shared.createGreetingSpeeches(language: languageSetting)
                let isDefaultSpeech = defaultSpeeches.contains { $0.id == id }
                
                if !isDefaultSpeech {
                    SpeechTextRepository.shared.delete(id: id)
                    
                    // 削除後にリストを更新
                    state.speeches = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)
                    
                    // 削除成功のフィードバックを表示
                    state.showSuccess = true
                    
                    return .run { send in
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
                        await send(.dismissSuccess)
                    }
                }
                
                return .none
            case .setKeyboardFocus(let isFocused):
                state.isKeyboardFocused = isFocused
                return .none
            }
        }
    }
}
