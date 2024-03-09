//
//  LanguageSettingView.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/02/12.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct LanguageSettingView: View {
    let store: Store<SettingsReducer.State, SettingsReducer.Action>

    var body: some View {
        NavigationView {
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                VStack{
                    Form {
                        Section(header: Text("Language")) {
                            NavigationLink(destination: LanguageSelectionView(store: store)) {
                                HStack(content: {
                                    Text("Select Language")
                                    Spacer()
                                    Text(viewStore.languageSetting ?? "")
                                })
                            }
                        }
                    }
                    Spacer()
                }
                .navigationBarTitle("Settings",displayMode: .inline)
                .onAppear {
                    viewStore.send(.onAppear)
                }
            }
        }
    }
}


struct LanguageSelectionView: View {
    let store: Store<SettingsReducer.State, SettingsReducer.Action>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            List {
                ForEach(SettingsReducer.State.availableLanguages, id: \.1) { language in
                    Button(language.0) {
                        viewStore.send(.setLanguage(language.1))
                    }
                }
            }
            .navigationBarTitle("Select Language", displayMode: .inline)
        }
    }
}


struct SettingsReducer: Reducer {
    struct State: Equatable {
        var languageSetting: String?
        static let availableLanguages = [("English", "en"), ("Japanese", "ja")]
    }

    enum Action: Equatable, Sendable {
        case setLanguage(String?)
        case onAppear
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
            }
        }
    }
}
