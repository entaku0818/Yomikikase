//
//  MainView.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/05/26.
//

import SwiftUI
import ComposableArchitecture
import Dependencies

struct MainView: View {
    let store: Store<Speeches.State, Speeches.Action>
    @State private var showingDevelopmentAlert = false
    @State private var developmentFeatureName = ""
    
    // 設定画面用のストアを作成
    let settingStore = Store(
        initialState: SettingsReducer.State(languageSetting: UserDefaultsManager.shared.languageSetting)) {
            SettingsReducer()
    }

    var body: some View {
        TabView {
            HomeView(
                store: store,
                onDevelopmentFeature: { featureName in
                    showDevelopmentAlert(for: featureName)
                    trackTabClick("development_feature")
                }
            )
                .tabItem {
                    Image(systemName: "house")
                    Text("ホーム")
                }
                .tag(0)
                .onAppear {
                    trackTabClick("home")
                }
            
            MyFilesView()
                .tabItem {
                    Image(systemName: "doc")
                    Text("マイファイル")
                }
                .tag(1)
                .onAppear {
                    trackTabClick("my_files")
                }
            
            // 設定
            NavigationStack {
                LanguageSettingView(store: settingStore)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("設定")
            }
            .tag(2)
            .onAppear {
                trackTabClick("settings")
            }
        }
        .alert("機能開発中", isPresented: $showingDevelopmentAlert) {
            Button("OK") { }
        } message: {
            Text("\(developmentFeatureName)機能は現在開発中です。今後のアップデートをお楽しみに！")
        }
    }
    
    private func trackTabClick(_ tabName: String) {
        @Dependency(\.analytics) var analytics
        analytics.logEvent("tab_clicked", [
            "tab_name": tabName,
            "screen": "main_tab_view"
        ])
    }
    
    private func showDevelopmentAlert(for featureName: String) {
        developmentFeatureName = featureName
        showingDevelopmentAlert = true
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
