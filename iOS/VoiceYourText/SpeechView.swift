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
import Dependencies

struct Speeches: Reducer {

    struct Speech: Identifiable, Equatable {
        var id: UUID
        var title: String
        var text: String
        var isDefault: Bool  // デフォルトの言葉かどうかを示すフラグ
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date? = nil  // ソフトデリート用
    }

    struct State: Equatable {
        @PresentationState var alert: AlertState<AlertAction>?
        var speechList: IdentifiedArrayOf<Speech> = []
        var currentText: String
        var isMailComposePresented: Bool = false
        var highlightedRange: NSRange? = nil
        var isSpeaking: Bool = false
        var nowPlaying: NowPlayingFeature.State = .init()
    }

    @CasePathable
    enum Action: Equatable, Sendable {
        case onAppear
        case onTap
        case currentTextChanged(String)
        case speechSelected(String)
        case alert(PresentationAction<AlertAction>)
        case mailComposeDismissed
        case startSpeaking
        case stopSpeaking
        case highlightRange(NSRange?)
        case speechFinished
        case nowPlaying(NowPlayingFeature.Action)
    }

    enum AlertAction: Equatable {
        case onAddReview
        case onGoodReview
        case onBadReview
        case onMailTap
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.nowPlaying, action: \.nowPlaying) {
            NowPlayingFeature()
        }

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
            case .startSpeaking:
                state.isSpeaking = true
                return .none
            case .stopSpeaking:
                state.isSpeaking = false
                state.highlightedRange = nil
                return .none
            case .highlightRange(let range):
                state.highlightedRange = range
                return .none
            case .speechFinished:
                state.isSpeaking = false
                state.highlightedRange = nil
                // nowPlayingも停止
                state.nowPlaying.isPlaying = false
                state.nowPlaying.progress = 1.0
                return .none

            case .nowPlaying(.stopPlaying):
                // ミニプレイヤーから停止された場合、ローカルのisSpeakingも更新
                state.isSpeaking = false
                state.highlightedRange = nil
                return .none

            case .nowPlaying:
                // その他のnowPlayingアクションはNowPlayingFeatureで処理
                return .none
            }
        }.ifLet(\.$alert, action: /Action.alert)

    }

}

struct SpeechView: View {
    @Dependency(\.speechSynthesizer) var speechSynthesizer
    let store: Store<Speeches.State, Speeches.Action>

    @State private var showingSpeedPicker = false

    let settingStore = Store(
        initialState: SettingsReducer.State(languageSetting: UserDefaultsManager.shared.languageSetting)) {
            SettingsReducer()
    }

    private let speedOptions: [Float] = [0.35, 0.5, 0.6, 0.75, 1.0]

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) {  viewStore in
            NavigationStack {
                VStack(spacing: 0) {
                    HighlightableTextView(
                        text: viewStore.binding(
                            get: \.currentText,
                            send: Speeches.Action.currentTextChanged
                        ),
                        highlightedRange: viewStore.binding(
                            get: \.highlightedRange,
                            send: Speeches.Action.highlightRange
                        ),
                        isEditable: true,
                        fontSize: 16
                    )
                    .frame(height: 100)
                    .padding(4)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding()

                    List {
                        ForEach(viewStore.speechList) { speech in
                            SpeechRowView(text: speech.title)
                                .onTapGesture {
                                    viewStore.send(.speechSelected(speech.text))
                                }
                        }
                    }

                    // プレイヤーコントロール
                    PlayerControlView(
                        isSpeaking: viewStore.isSpeaking,
                        isTextEmpty: viewStore.currentText.isEmpty,
                        speechRate: UserDefaultsManager.shared.speechRate,
                        onPlay: {
                            speakWithHighlight(text: viewStore.currentText, viewStore: viewStore)
                        },
                        onStop: {
                            stopSpeaking(viewStore: viewStore)
                        },
                        onSpeedTap: {
                            showingSpeedPicker = true
                        }
                    )

                    if !UserDefaultsManager.shared.isPremiumUser {
                        AdmobBannerView().frame(width: .infinity, height: 50)
                    }
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
                .confirmationDialog("再生速度", isPresented: $showingSpeedPicker, titleVisibility: .visible) {
                    ForEach(speedOptions, id: \.self) { speed in
                        Button(formatSpeedOption(speed)) {
                            UserDefaultsManager.shared.speechRate = speed
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                .navigationTitle("Voice Narrator")
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .alert(store: self.store.scope(state: \.$alert, action: Speeches.Action.alert))
            }
        }
    }

    private func formatSpeedOption(_ rate: Float) -> String {
        let displayRate = rate / AVSpeechUtteranceDefaultSpeechRate
        if displayRate == 1.0 {
            return "1x（標準）"
        } else if displayRate < 1.0 {
            return String(format: "%.1fx（遅い）", displayRate)
        } else {
            return String(format: "%.1fx（速い）", displayRate)
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

        Task {
            try? await speechSynthesizer.speak(speechUtterance)
        }
    }

    func stopSpeaking() {
        Task {
            _ = await speechSynthesizer.stopSpeaking()
        }
    }

    func speakWithHighlight(text: String, viewStore: ViewStoreOf<Speeches>) {
        guard !text.isEmpty else {
            print("Cannot speak: text is empty")
            return
        }

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

        viewStore.send(.startSpeaking)
        // ミニプレイヤー用にnowPlayingも更新
        let title = String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        viewStore.send(.nowPlaying(.startPlaying(title: title, text: text, source: .textInput)))

        Task {
            do {
                try await speechSynthesizer.speakWithHighlight(
                    speechUtterance,
                    { range, speechString in
                        // ハイライト更新
                        DispatchQueue.main.async {
                            viewStore.send(.highlightRange(range))
                        }
                    },
                    {
                        // 読み上げ完了
                        DispatchQueue.main.async {
                            viewStore.send(.speechFinished)
                        }
                    }
                )
            } catch {
                print("Speech synthesis failed: \(error)")
                DispatchQueue.main.async {
                    viewStore.send(.speechFinished)
                }
            }
        }
    }

    func stopSpeaking(viewStore: ViewStoreOf<Speeches>) {
        viewStore.send(.stopSpeaking)
        viewStore.send(.nowPlaying(.stopPlaying))
        Task {
            _ = await speechSynthesizer.stopSpeaking()
        }
    }

    func speakWithAPI(text: String, viewStore: ViewStoreOf<Speeches>) {
        guard !text.isEmpty else { return }
        
        viewStore.send(.startSpeaking)
        
        Task {
            do {
                // 現在の言語設定から適切なvoiceIdを決定
                let languageCode = UserDefaultsManager.shared.languageSetting ?? "ja"
                let voiceId = languageCode.hasPrefix("ja") ? "ja-jp-female-a" : "en-us-female-a"
                
                let success = try await speechSynthesizer.speakWithAPI(text, voiceId)
                
                DispatchQueue.main.async {
                    if success {
                        viewStore.send(.speechFinished)
                    } else {
                        viewStore.send(.stopSpeaking)
                    }
                }
            } catch {
                print("API speech failed: \(error)")
                DispatchQueue.main.async {
                    viewStore.send(.stopSpeaking)
                }
            }
        }
    }

    func speechMyVoice(text: String) {
        if #available(iOS 17.0, *) {
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                if status == .authorized {
                    let personalVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
                    let myUtterance = AVSpeechUtterance(string: text)
                    myUtterance.voice = personalVoices.first
                    Task {
                        try? await speechSynthesizer.speak(myUtterance)
                    }
                }
            }
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
