//
//  ContentView.swift
//  Yomikikase
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import SwiftUI
import AVFoundation
import ComposableArchitecture

struct Speeches: Reducer {
    struct Speech: Identifiable, Equatable {
        var id: UUID
        var text: String
        var createdAt: Date
        var updatedAt: Date
    }

    struct State: Equatable {
        var speechList: IdentifiedArrayOf<Speech> = []
        var currentText: String
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case onTap
        case currentTextChanged(String)

    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:

                let texts = SpeechTextRepository.shared.fetchAllSpeechText()

                state.speechList = IdentifiedArrayOf(uniqueElements: texts)

                return .none
            case .onTap:
                return .none
            case .currentTextChanged(let newText):
                state.currentText = newText
                return .none
            }
        }
    }
}

struct SpeechView: View  {
    private let speechSynthesizer = AVSpeechSynthesizer() // AVSpeechSynthesizerのインスタンス

    let store: Store<Speeches.State, Speeches.Action>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) {  viewStore in
            VStack {
                TextEditor(text: viewStore.binding(
                    get: \.currentText,
                    send: Speeches.Action.currentTextChanged
                ))
                .frame(height: 100)
                .border(Color.gray, width: 1) 
                .padding()

                Button("読み上げる") {
                    speak(text: viewStore.currentText)
                }
                .padding()

                Button("自分の声で読み上げる") {
                    speechMyVoice(text: viewStore.currentText)
                }
                .padding()

                List {
                    // SpeechListの表示
                    ForEach(viewStore.speechList) { speech in
                        SpeechRowView(text: speech.text)
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .padding()
        }
    }

    func speak(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")

        speechSynthesizer.speak(speechUtterance)
    }

    func speechMyVoice(text: String){

        let synthesizer = AVSpeechSynthesizer()

        AVSpeechSynthesizer.requestPersonalVoiceAuthorization(completionHandler: { status in
            if status == .authorized {
                let personalVoices = AVSpeechSynthesisVoice.speechVoices().filter{$0.voiceTraits.contains(.isPersonalVoice)}
                let myUtterance = AVSpeechUtterance(string: text)
                myUtterance.voice = personalVoices.first
                synthesizer.speak(myUtterance)
            }
        })
    }

}

struct SpeechRowView: View {
    let text: String

    var body: some View {
        VStack{
            Text(text)
        }
    }
}

struct SpeechView_Previews: PreviewProvider {
    static var previews: some View {
        // ダミーの初期ステートを設定
        let initialState = Speeches.State(
            speechList: IdentifiedArrayOf(uniqueElements: [
                Speeches.Speech(id: UUID(), text: "テストスピーチ1", createdAt: Date(), updatedAt: Date()),
                Speeches.Speech(id: UUID(), text: "テストスピーチ2", createdAt: Date(), updatedAt: Date())
            ]), currentText: ""
        )

        // SpeechViewにStoreを渡してプレビュー
        return SpeechView(store: 
                Store(initialState: initialState, reducer: {

            })
        )
    }
}
