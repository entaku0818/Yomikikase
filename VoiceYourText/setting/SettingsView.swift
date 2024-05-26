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

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("タイトル")) {
                        TextField("タイトルを入力", text: viewStore.binding(
                            get: \.title,
                            send: SettingsReducer.Action.setTitle
                        ))
                    }
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

                               Text("文字数: \(viewStore.text.count)")
                                   .foregroundColor(.gray)
                                   .frame(maxWidth: .infinity, alignment: .trailing)
                                   .padding(.top, 4)
                           }
                       }
                    Button(action: {
                        viewStore.send(.insert)
                    }) {
                        Text("保存")
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
                        }
                    }
                }
                .navigationTitle("読み上げ設定")
                .onAppear {
                    viewStore.send(.fetchSpeeches)
                }
            }
        }
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        return SettingsView(store: Store(
            initialState: SettingsReducer.State(languageSetting: "en"),
            reducer: {
                SettingsReducer()
            })
        )
    }
}
