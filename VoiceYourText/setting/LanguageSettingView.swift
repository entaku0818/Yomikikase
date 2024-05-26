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


