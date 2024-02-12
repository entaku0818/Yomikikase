//
//  LanguageSettingView.swift
//  Yomikikase
//
//  Created by 遠藤拓弥 on 2024/02/12.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct LanguageSettingView: View {
    let store: Store<SettingsReducer.State, SettingsReducer.Action>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) {  viewStore in
            Form {
                Section(header: Text("Language")) {
                    Button("Select English") {
                        viewStore.send(.setLanguage("en"))
                    }
                    Button("Select Japanese") {
                        viewStore.send(.setLanguage("ja"))
                    }
                }
            }.onAppear(perform: {
                viewStore.send(.onAppear)
            })
        }
    }
}


struct SettingsReducer: Reducer {

    
    struct State: Equatable {
        var languageSetting: String? // 言語設定を保持するためのプロパティ
    }

    enum Action: Equatable, Sendable {
        case setLanguage(String?) // 言語設定を変更するアクション
        case onAppear // UserDefaultsから言語設定を読み込むアクション
    }



    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setLanguage(let languageCode):
                state.languageSetting = languageCode
                // UserDefaultsに言語設定を保存
                UserDefaultsManager.shared.languageSetting = languageCode
                return .none
            case .onAppear:
                // UserDefaultsから言語設定を読み込み、stateを更新
                state.languageSetting = UserDefaultsManager.shared.languageSetting
                return .none
            }
        }
    }
}
