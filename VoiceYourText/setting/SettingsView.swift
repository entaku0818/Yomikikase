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

                                   HStack {
                                       Text("文字数: \(viewStore.text.count)")
                                           .foregroundColor(.gray)
                                       
                                       Spacer()
                                       
                                       Button(action: {
                                           viewStore.send(.insert)
                                           isTextFieldFocused = false
                                       }) {
                                           Text("保存")
                                               .foregroundColor(.blue)
                                               .padding(.horizontal, 12)
                                               .padding(.vertical, 6)
                                               .background(
                                                   RoundedRectangle(cornerRadius: 8)
                                                       .stroke(Color.blue, lineWidth: 1)
                                               )
                                       }
                                   }
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
                                        viewStore.send(.confirmDelete(speech.id))
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    // 広告バナーを追加
                    if !UserDefaultsManager.shared.isPremiumUser {
                        AdmobBannerView().frame(width: .infinity, height: 50)
                    }
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
                                    Text(viewStore.successMessage)
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
                                    .frame(minWidth: 250, maxWidth: .infinity, minHeight: 50, maxHeight: 100)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.white)
                                    Text(viewStore.errorMessage)
                                        .foregroundColor(.white)
                                        .bold()
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            .transition(.opacity)
                            .animation(.easeInOut, value: viewStore.showError)
                        ) : AnyView(EmptyView())
                )
                .alert("削除の確認", isPresented: viewStore.binding(
                    get: \.showDeleteConfirmation,
                    send: { _ in .cancelDelete }
                )) {
                    Button("キャンセル", role: .cancel) {
                        viewStore.send(.cancelDelete)
                    }
                    Button("削除", role: .destructive) {
                        viewStore.send(.executeDelete)
                    }
                } message: {
                    Text("このアイテムを削除してもよろしいですか？")
                }
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
