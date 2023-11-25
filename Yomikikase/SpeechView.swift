//
//  ContentView.swift
//  Yomikikase
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import SwiftUI
import AVFoundation

struct SpeechView: View {
    @State private var textToSpeak = "" // テキスト入力を保持するための変数
    private let speechSynthesizer = AVSpeechSynthesizer() // AVSpeechSynthesizerのインスタンス

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            TextField("テキストを入力", text: $textToSpeak)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("読み上げる") {
                speak(text: textToSpeak)
            }
            .padding()

            Button("自分の声で読み上げる") {
                speak(text: textToSpeak)
            }
            .padding()
        }
        .padding()
    }

    func speak(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
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


struct Speechs: Reducer {
    struct Photo: Identifiable, Equatable {

        var id: UUID
        var name: String
        var imageURL: URL
    }

    struct State: Equatable {
        var photos: IdentifiedArrayOf<Photo> = []

        var filteredPhotos: IdentifiedArrayOf<Photo> {
            return self.photos  // 今回はフィルタリングのロジックを省略しています
        }
    }

    enum Action: BindableAction, Equatable, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case delete(IndexSet)
        case photoTapped(id: Photo.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:

                let repositoryPhotos = PhotoRepository.shared.fetchAllPhotos()

                state.photos = IdentifiedArrayOf(uniqueElements: repositoryPhotos)

                return .none
            case .binding:
                return .none

            case let .delete(indexSet):
                state.photos.remove(atOffsets: indexSet)
                return .none

            case .photoTapped(let id):
                // ここで写真をタップしたときの処理を追加できます
                return .none
            }
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SpeechView()
    }
}
