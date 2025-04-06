//
//  SettingsView.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/05/26.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: Store<SettingsReducer.State, SettingsReducer.Action>
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack {
                    Form {
                        Section(header: Text("内容")) {
                               VStack {
                                   TextEditor(text: viewStore.binding(
                                       get: \.text,
                                       send: SettingsReducer.Action.setText
                                   ))
                                   .frame(height: 150)
                                   .overlay(
                                       RoundedRectangle(cornerRadius: 8)
                                           .stroke(Color.gray, lineWidth: 1)
                                   )
                                   .focused($isTextFieldFocused)
                                   .onChange(of: isTextFieldFocused) { newValue in
                                       viewStore.send(.setKeyboardFocus(newValue))
                                   }
                                   .onChange(of: viewStore.isKeyboardFocused) { newValue in
                                       if !newValue {
                                           isTextFieldFocused = false
                                       }
                                   }
                                   .toolbar {
                                       ToolbarItemGroup(placement: .keyboard) {
                                           Spacer()
                                           Button("保存") {
                                               viewStore.send(.insert)
                                           }
                                       }
                                   }

                                   Text("文字数: \(viewStore.text.count)")
                                       .foregroundColor(.gray)
                                       .frame(maxWidth: .infinity, alignment: .trailing)
                                       .padding(.top, 4)
                               }
                        }
                        
                        Section(header: Text("読み上げ一覧")) {
                            List(viewStore.speeches) { speech in
                                VStack(alignment: .leading) {
                                    Text(speech.title)
                                        .font(.headline)
                                    Text(speech.createdAt, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewStore.send(.deleteSpeech(speech.id))
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    // 広告バナーを追加
                    AdmobBannerView().frame(width: .infinity, height: 50)
                }
                .navigationTitle("読み上げ設定")
                .onAppear {
                    viewStore.send(.fetchSpeeches)
                }
                .overlay(
                    viewStore.showSuccess ? 
                        AnyView(
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: 200, height: 50)
                                
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                    Text("保存しました")
                                        .foregroundColor(.white)
                                        .bold()
                                }
                            }
                            .transition(.opacity)
                            .animation(.easeInOut, value: viewStore.showSuccess)
                        ) : 
                    viewStore.showError ?
                        AnyView(
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: 250, height: 50)
                                
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.white)
                                    Text(viewStore.errorMessage)
                                        .foregroundColor(.white)
                                        .bold()
                                }
                            }
                            .transition(.opacity)
                            .animation(.easeInOut, value: viewStore.showError)
                        ) : AnyView(EmptyView())
                )
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: Store(
            initialState: SettingsReducer.State(languageSetting: "en"))            {
                SettingsReducer()
            }
        )
    }
}
