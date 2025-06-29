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
    
    // 設定画面用のストアを作成
    let settingStore = Store(
        initialState: SettingsReducer.State(languageSetting: UserDefaultsManager.shared.languageSetting)) {
            SettingsReducer()
    }

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem {
                    Image(systemName: "house")
                    Text("ホーム")
                }
                .tag(0)
            
            MyFilesView()
                .tabItem {
                    Image(systemName: "doc")
                    Text("マイファイル")
                }
                .tag(1)
            
            NavigationStack {
                LanguageSettingView(store: settingStore)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("設定")
            }
            .tag(2)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let initialState = Speeches.State(
            speechList: IdentifiedArrayOf(uniqueElements: [
                Speeches.Speech(id: UUID(), title: "スピーチ1", text: "テストスピーチ1", isDefault: false, createdAt: Date(), updatedAt: Date()),
                Speeches.Speech(id: UUID(), title: "スピーチ2", text: "テストスピーチ2", isDefault: false, createdAt: Date(), updatedAt: Date())
            ]), currentText: ""
        )

        return MainView(store:
                Store(initialState: initialState) {
                    Speeches()
                }
        )
    }
}
