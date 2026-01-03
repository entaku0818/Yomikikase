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
        ZStack(alignment: .bottom) {
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

                MyFilesView(store: store)
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

            // ミニプレイヤー（コンテンツがある場合に表示）
            WithViewStore(store, observe: { !$0.nowPlaying.currentTitle.isEmpty }) { viewStore in
                if viewStore.state {
                    MiniPlayerView(
                        store: store.scope(
                            state: \.nowPlaying,
                            action: Speeches.Action.nowPlaying
                        )
                    )
                    // TabBarの高さ + 広告の高さ（非プレミアムユーザーの場合）
                    .padding(.bottom, UserDefaultsManager.shared.isPremiumUser ? 49 : 99)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: store.withState { !$0.nowPlaying.currentTitle.isEmpty })
        }
        .alert("機能開発中", isPresented: $showingDevelopmentAlert) {
            Button("OK") { }
        } message: {
            Text("\(developmentFeatureName)機能は現在開発中です。今後のアップデートをお楽しみに！")
        }
        // ミニプレイヤーからのナビゲーション
        .fullScreenCover(
            item: Binding(
                get: { store.withState { $0.navigationSource } },
                set: { _ in store.send(.dismissNavigation) }
            )
        ) { source in
            navigationDestination(for: source)
        }
    }

    @ViewBuilder
    private func navigationDestination(for source: PlaybackSource) -> some View {
        switch source {
        case .textInput(let fileId, let text):
            TextInputView(
                store: store,
                initialText: text,
                fileId: fileId
            )
        case .pdf(_, let url):
            PDFReaderView(
                store: Store(
                    initialState: PDFReaderFeature.State(currentPDFURL: url)
                ) {
                    PDFReaderFeature()
                },
                parentStore: store
            )
        case .speech:
            // SpeechViewへの戻りは現状サポートしない
            EmptyView()
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
