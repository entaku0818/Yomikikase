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
                    Text("VoiceYourText")
                }
            Text("Tab 2")
                .tabItem {
                    Image(systemName: "star")
                    Text("Tab 2")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let initialState = Speeches.State(
            speechList: IdentifiedArrayOf(uniqueElements: [
                Speeches.Speech(id: UUID(), text: "テストスピーチ1", createdAt: Date(), updatedAt: Date()),
                Speeches.Speech(id: UUID(), text: "テストスピーチ2", createdAt: Date(), updatedAt: Date())
            ]), currentText: ""
        )

        return MainView(store:
                Store(initialState: initialState, reducer: {
                    Speeches()
                })
        )
    }
}
