//
//  Speeches.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import SwiftUI
import AVFoundation
import ComposableArchitecture
import StoreKit

struct Speeches: Reducer {

    struct Speech: Identifiable, Equatable {
        var id: UUID
        var title: String
        var text: String
        var isDefault: Bool  // デフォルトの言葉かどうかを示すフラグ
        var createdAt: Date
        var updatedAt: Date
    }

    struct State: Equatable {
        @PresentationState var alert: AlertState<AlertAction>?
        var speechList: IdentifiedArrayOf<Speech> = []
        var currentText: String
        var isMailComposePresented: Bool = false

    }

    enum Action: Equatable, Sendable {
        case onAppear
        case onTap
        case currentTextChanged(String)
        case speechSelected(String)
        case alert(PresentationAction<AlertAction>)
        case mailComposeDismissed
    }

    enum AlertAction: Equatable {
        case onAddReview
        case onGoodReview
        case onBadReview
        case onMailTap
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:

                let languageCode: String = UserDefaultsManager.shared.languageSetting ?? "en"

                let languageSetting: SpeechTextRepository.LanguageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english

                let texts = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)

                state.speechList = IdentifiedArrayOf(uniqueElements: texts)

              let installDate = UserDefaultsManager.shared.installDate
              let reviewCount = UserDefaultsManager.shared.reviewRequestCount

              // 初回起動時
              if let installDate = installDate {
                  let currentDate = Date()
                  if let interval = Calendar.current.dateComponents([.day], from: installDate, to: currentDate).day {
                      if interval >= 2 && reviewCount == 0 {
                            state.alert = AlertState {
                                TextState("このアプリについて")
                            } actions: {
                                ButtonState(action: .send(.onGoodReview)) {
                                    TextState("はい")
                                }
                                ButtonState(action: .send(.onBadReview)) {
                                    TextState("いいえ、フィードバックを送信")
                                }
                            } message: {
                                TextState(
                                    "Voice Narratorに満足していますか？"
                                )
                            }
                          UserDefaultsManager.shared.reviewRequestCount = reviewCount + 1

                      }
                  }
              } else {
                  UserDefaultsManager.shared.installDate = Date()
              }

              return .none

            case .onTap:
                return .none
            case .currentTextChanged(let newText):
                state.currentText = newText
                return .none
            case .speechSelected(let selectedText):
                state.currentText = selectedText
                return .none

            case .alert(.presented(.onAddReview)):

                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                    return .none
            case .alert(.presented(.onGoodReview)):

                    state.alert = AlertState(
                      title: TextState("Voice Narratorについて"),
                      message: TextState("ご利用ありがとうございます！次の画面でアプリの評価をお願いします。"),
                      dismissButton: .default(TextState("OK"),
                                                               action: .send(.onAddReview))
                    )
                    return .none
            case .alert(.presented(.onBadReview)):

                    state.alert = AlertState(
                      title: TextState("ご不便かけて申し訳ありません"),
                      message: TextState("次の画面のメールにて詳細に状況を教えてください。"),
                      dismissButton: .default(TextState("OK"),
                      action: .send(.onMailTap))
                    )
                    return .none

            case .alert(.presented(.onMailTap)):

                state.alert = nil
                state.isMailComposePresented.toggle()
                return .none
            case .mailComposeDismissed:
                state.isMailComposePresented = false
                return .none
            case .alert(.dismiss):
                return .none

            }
        }.ifLet(\.$alert, action: /Action.alert)

    }

}

struct SpeechView: View {
    private let speechSynthesizer = AVSpeechSynthesizer() // AVSpeechSynthesizerのインスタンス

    let store: Store<Speeches.State, Speeches.Action>

    let settingStore = Store(
        initialState: SettingsReducer.State(languageSetting: UserDefaultsManager.shared.languageSetting)) {
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
                    .padding(4)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding()

                    HStack (spacing: 8){
                        Button(action: { speak(text: viewStore.currentText) }) {
                            Image(systemName: "play.fill")
                            Text("読み上げ開始")
                        }

                        Button(action: { stopSpeaking() }) {
                            Image(systemName: "stop.fill")
                            Text("停止")
                        }
                        .padding()
                    }

                    List {
                        ForEach(viewStore.speechList) { speech in
                            SpeechRowView(text: speech.title)
                                .onTapGesture {
                                    viewStore.send(.speechSelected(speech.text))

                                }
                        }
                    }
                    AdmobBannerView().frame(width: .infinity, height: 50)
                }
                .sheet(
                  isPresented: viewStore.binding(
                    get: \.isMailComposePresented,
                    send: Speeches.Action.mailComposeDismissed
                  )
                ) {
                  MailComposeViewControllerWrapper(
                    isPresented: viewStore.binding(
                      get: \.isMailComposePresented,
                      send: Speeches.Action.mailComposeDismissed
                    )
                  )
                }
                .navigationTitle("Voice Narrator")
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .alert(store: self.store.scope(state: \.$alert, action: Speeches.Action.alert))
            }
        }
    }

    func speak(text: String) {
        let audioSession = AVAudioSession.sharedInstance()
         do {
             try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
             try audioSession.setActive(true)
         } catch {
             print("Failed to set audio session category: \(error)")
         }
        let speechUtterance = AVSpeechUtterance(string: text)

        // 保存された言語設定を取得
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)

        // 保存されたレートとピッチを取得し、デフォルト値を設定
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75 // 音量は固定

        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume

        speechSynthesizer.speak(speechUtterance)
    }

    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    func speechMyVoice(text: String) {

        let synthesizer = AVSpeechSynthesizer()

        if #available(iOS 17.0, *) {
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                if status == .authorized {
                    let personalVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
                    let myUtterance = AVSpeechUtterance(string: text)
                    myUtterance.voice = personalVoices.first
                    synthesizer.speak(myUtterance)
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }

}

struct SpeechRowView: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
        }
    }
}

struct SpeechView_Previews: PreviewProvider {
    static var previews: some View {
        // ダミーの初期ステートを設定
        let initialState = Speeches.State(
            speechList: IdentifiedArrayOf(uniqueElements: [
                Speeches.Speech(id: UUID(), title: "スピーチ1", text: "テストスピーチ1", isDefault: false, createdAt: Date(), updatedAt: Date()),
                Speeches.Speech(id: UUID(), title: "スピーチ2", text: "テストスピーチ2", isDefault: false, createdAt: Date(), updatedAt: Date())
            ]), currentText: ""
        )

        // SpeechViewにStoreを渡してプレビュー
        return SpeechView(store:
                Store(initialState: initialState) {

            }
        )
    }
}
