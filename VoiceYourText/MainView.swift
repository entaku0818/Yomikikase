//
//  MainView.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/05/26.
//

import SwiftUI
import ComposableArchitecture


struct MainView: View {
    let store: Store<Speeches.State, Speeches.Action>

    var body: some View {
        TabView {
            SpeechView(store: store)
                .tabItem {
                    Image(systemName: "text.bubble")
                    Text("読み上げ")
                }
            SettingsView(store: Store(
                initialState: SettingsReducer.State(languageSetting: "en"),
                reducer: {
                    SettingsReducer()
                })
            )
                .tabItem {
                    Image(systemName: "star")
                    Text("読み上げ内容登録")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let initialState = Speeches.State(
            speechList: IdentifiedArrayOf(uniqueElements: [
                Speeches.Speech(id: UUID(), title: "スピーチ1", text: "テストスピーチ1", createdAt: Date(), updatedAt: Date()),
                Speeches.Speech(id: UUID(), title: "スピーチ2", text: "テストスピーチ2", createdAt: Date(), updatedAt: Date())
            ]), currentText: ""
        )

        return MainView(store:
                Store(initialState: initialState, reducer: {
                    Speeches()
                })
        )
    }
}
