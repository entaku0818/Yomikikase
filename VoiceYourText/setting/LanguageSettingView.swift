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
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                VStack {
                    Form {
                        Section(header: Text("Language")) {
                            NavigationLink(destination: LanguageSelectionView(store: store)) {
                                HStack {
                                    Text("Select Language")
                                    Spacer()
                                    Text(viewStore.languageSetting ?? "")
                                }
                            }
                        }

                        Section(header: Text("声の速さ")) {
                            HStack {
                                Image(systemName: "tortoise.fill")

                                Slider(value: viewStore.binding(
                                    get: \.speechRate,
                                    send: SettingsReducer.Action.setSpeechRate
                                ), in: 0.0...2.0, step: 0.1)
                                Image(systemName: "hare.fill")

                            }
                        }
                        Section(header: Text("声の高さ")) {
                            HStack {
                                Image(systemName: "speaker.wave.1")
                                Slider(value: viewStore.binding(
                                    get: \.speechPitch,
                                    send: SettingsReducer.Action.setSpeechPitch
                                ), in: 0.5...2.0, step: 0.1)
                                Image(systemName: "speaker.wave.3")

                            }
                        }
                            Button(action: {
                                            viewStore.send(.resetToDefault)
                                        }) {
                                            Text("読み上げ設定をデフォルト値に戻す")
                                                .foregroundColor(.red)
                            }

                    }
                    Spacer()
                    AdmobBannerView().frame(width: .infinity, height: 50)
                }
                .navigationBarTitle("Settings")
                .onAppear {
                    viewStore.send(.onAppear)
                }
            }

    }
}

struct LanguageSelectionView: View {
    let store: Store<SettingsReducer.State, SettingsReducer.Action>
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            List {
                ForEach(SettingsReducer.State.availableLanguages, id: \.1) { language in
                    Button(language.0) {
                        viewStore.send(.setLanguage(language.1))
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarTitle("Select Language", displayMode: .inline)
        }
    }
}
