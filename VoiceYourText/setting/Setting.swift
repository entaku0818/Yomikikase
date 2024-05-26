//
//  Setting.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/05/26.
//

import SwiftUI
import ComposableArchitecture

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
    }

    enum Action: Equatable, Sendable {
        case setLanguage(String?)
        case onAppear
        case setTitle(String)
        case setText(String)
        case insert
        case fetchSpeeches
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
                return .none

            case .setTitle(let title):
                state.title = title
                return .none

            case .setText(let text):
                state.text = text
                return .none

            case .insert:
                guard let languageCode = UserDefaultsManager.shared.languageSetting else { return .none }
                let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
                SpeechTextRepository.shared.insert(title: state.title, text: state.text, languageSetting: languageSetting)

                state.title = ""
                state.text = ""

                return .none

            case .fetchSpeeches:
                guard let languageCode = UserDefaultsManager.shared.languageSetting else { return .none }
                let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
                state.speeches = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)
                return .none

            }
        }
    }
}

