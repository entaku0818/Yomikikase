//
//  LanguageSettingView.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/02/12.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import AVFAudio

@ViewAction(for: SettingsReducer.self)
struct LanguageSettingView: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack {
            Form {

                Section(header: Text("プレミアム機能")) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("プレミアムにアップグレード")
                                    .font(.headline)
                                Text("より快適な読み上げ体験を")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }


                        Button(action: {
                            send(.navigateToSubscription)
                        }) {
                            HStack {
                                Text("今すぐアップグレード")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                Section(header: Text("音声設定")) {
                    NavigationLink(destination: VoiceSettingView(store: store)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("音声の選択")
                                Spacer()
                                if let identifier = store.selectedVoiceIdentifier,
                                   let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                                    Text(voice.name)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // 話速の調整
                        VStack(alignment: .leading, spacing: 8) {
                            Text("声の速さ")
                                .font(.headline)
                            HStack {
                                Image(systemName: "tortoise.fill")
                                    .foregroundColor(.gray)
                                Slider(value: $store.speechRate, in: 0.0...2.0, step: 0.1)
                                Image(systemName: "hare.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // 声の高さの調整
                        VStack(alignment: .leading, spacing: 8) {
                            Text("声の高さ")
                                .font(.headline)
                            HStack {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.gray)
                                Slider(value: $store.speechPitch, in: 0.5...2.0, step: 0.1)
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("辞書")) {
                    NavigationLink(destination: UserDictionaryView(
                        store: Store(
                            initialState: UserDictionaryReducer.State()
                        ) {
                            UserDictionaryReducer()
                        }
                    )) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("ユーザー辞書")
                            Spacer()
                        }
                    }
                }
                


                Section(header: Text("言語設定")) {
                    NavigationLink(destination: LanguageSelectionView(store: store)) {
                        HStack {
                            Text("言語を選択")
                            Spacer()
                            Text(store.languageSetting ?? "")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Button(action: {
                    send(.resetToDefault)
                }) {
                    Text("読み上げ設定をデフォルト値に戻す")
                        .foregroundColor(.red)
                }
            }
            Spacer()
            if !UserDefaultsManager.shared.isPremiumUser {
                AdmobBannerView().frame(width: .infinity, height: 50)
            }
        }
        .navigationBarTitle("Settings")
        .onAppear {
            send(.onAppear)
        }
        .navigationDestination(
            isPresented: $store.showSubscriptionView
        ) {
            SubscriptionView()
        }
    }
}

@ViewAction(for: SettingsReducer.self)
struct LanguageSelectionView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        List {
            ForEach(SettingsReducer.State.availableLanguages, id: \.1) { language in
                Button(language.0) {
                    send(.setLanguage(language.1))
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .navigationBarTitle("Select Language", displayMode: .inline)
    }
}

struct PremiumFeatureRow: View {
    let iconName: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
