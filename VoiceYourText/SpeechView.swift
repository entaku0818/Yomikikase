//
//  ContentView.swift
//  VoiceYourText
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
        case speechSelected(String)
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
            case .speechSelected(let selectedText):
                state.currentText = selectedText
                return .none
            }
        }
    }
}

struct SpeechView: View  {
    private let speechSynthesizer = AVSpeechSynthesizer() // AVSpeechSynthesizerのインスタンス

    let store: Store<Speeches.State, Speeches.Action>

    let settingStore = Store(
        initialState: SettingsReducer.State(languageSetting: UserDefaultsManager.shared.languageSetting))
        {
            SettingsReducer()
        }


    var body: some View {
        WithViewStore(self.store, observe: { $0 }) {  viewStore in
            NavigationStack {
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

//                    Button("自分の声で読み上げる") {
//                        speechMyVoice(text: viewStore.currentText)
//                    }
//                    .padding()
                    List {
                        ForEach(viewStore.speechList) { speech in
                            SpeechRowView(text: speech.text)
                                .listRowBackground(Color.white)
                                .onTapGesture {
                                    viewStore.send(.speechSelected(speech.text))

                                }
                        }
                    }

                }
                .navigationTitle("Speech Synthesizer")
                 .toolbar {
                     ToolbarItem(placement: .navigationBarTrailing) {
                         NavigationLink(destination:
                            LanguageSettingView(store:settingStore)
                         ) {
                                 Image(systemName: "gear")
                                     .resizable()
                         }
                         .buttonStyle(PlainButtonStyle()) // ボタンのスタイルを調整

                     }
                 }
                .onAppear {
                    viewStore.send(.onAppear)
                }
            }
        }
    }

    func speak(text: String) {


        let speechUtterance:AVSpeechUtterance = AVSpeechUtterance.init(string: text)

        // Retrieve the saved language setting
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        

        // Adjust the rate, pitch, and volume for more natural sounding speech
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechUtterance.pitchMultiplier = 1.2 // Slightly higher pitch can sound more natural
        speechUtterance.volume = 0.75 // Adjust volume if needed


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
