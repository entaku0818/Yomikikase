//
//  Speeches.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import SwiftUI
import AVFoundation
import ComposableArchitecture
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
        var fileType: String? = nil  // "text", "pdf", "scan"
        var imagePath: String? = nil  // スキャン画像のパス（scanの場合のみ）
    }

    struct State: Equatable {
        var speechList: IdentifiedArrayOf<Speech> = []
        var currentText: String
        var highlightedRange: NSRange? = nil
        var isSpeaking: Bool = false
        var nowPlaying: NowPlayingFeature.State = .init()
        var navigationSource: PlaybackSource? = nil  // ミニプレイヤーからのナビゲーション用
    }

    @CasePathable
    enum Action: Equatable, Sendable {
        case onAppear
        case onTap
        case currentTextChanged(String)
        case speechSelected(String)
        case startSpeaking
        case stopSpeaking
        case highlightRange(NSRange?)
        case speechFinished
        case nowPlaying(NowPlayingFeature.Action)
        case dismissNavigation  // ナビゲーション画面を閉じる
    }

    @Dependency(\.analytics) var analytics

    var body: some Reducer<State, Action> {
        Scope(state: \.nowPlaying, action: \.nowPlaying) {
            NowPlayingFeature()
        }

        Reduce { [analytics] state, action in
            switch action {
            case .onAppear:

                let languageCode: String = UserDefaultsManager.shared.languageSetting ?? "en"

                let languageSetting: SpeechTextRepository.LanguageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english

                let texts = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)

                state.speechList = IdentifiedArrayOf(uniqueElements: texts)

                // 起動回数のカウントと起動時のレビュー依頼は VoiceYourTextApp の cold start 処理で行う。
                // ここ（onAppear）はスキャン保存後のリスト再取得などでも呼ばれるため判定を置かない。
                return .none

            case .onTap:
                return .none
            case .currentTextChanged(let newText):
                state.currentText = newText
                return .none
            case .speechSelected(let selectedText):
                state.currentText = selectedText
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
                let completedCount = UserDefaultsManager.shared.speechCompletedCount + 1
                UserDefaultsManager.shared.speechCompletedCount = completedCount
                analytics.logEvent("speech_completed", ["count": completedCount])
                return .none

            case .nowPlaying(.stopPlaying):
                // ミニプレイヤーから停止された場合、ローカルのisSpeakingも更新
                state.isSpeaking = false
                state.highlightedRange = nil
                return .none

            case .nowPlaying(.navigateToSource):
                // ミニプレイヤーをタップしたら元の画面を開く
                state.navigationSource = state.nowPlaying.source
                return .none

            case .nowPlaying:
                // その他のnowPlayingアクションはNowPlayingFeatureで処理
                return .none

            case .dismissNavigation:
                state.navigationSource = nil
                return .none
            }
        }

    }

}

struct SpeechView: View {
    @Dependency(\.speechSynthesizer) var speechSynthesizer
    let store: Store<Speeches.State, Speeches.Action>

    @State private var showingSpeedPicker = false
    @State private var isPremium: Bool = UserDefaultsManager.shared.isPremiumUser

    let settingStore = Store(
        initialState: SettingsReducer.State(languageSetting: UserDefaultsManager.shared.languageSetting)) {
            SettingsReducer()
    }

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
                        },
                        onTTSInfoTap: nil
                    )

                    if !isPremium {
                        AdmobBannerView().frame(width: .infinity, height: 50)
                    }
                }
                .confirmationDialog("再生速度", isPresented: $showingSpeedPicker, titleVisibility: .visible) {
                    ForEach(SpeechSettings.speedOptions, id: \.self) { speed in
                        Button(SpeechSettings.formatSpeedOption(speed)) {
                            UserDefaultsManager.shared.speechRate = speed
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                .navigationTitle("Voice Narrator")
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PremiumStatusDidChange"))) { _ in
                    isPremium = UserDefaultsManager.shared.isPremiumUser
                }
            }
        }
    }

    func speak(text: String) {
        let audioSession = AVAudioSession.sharedInstance()
         do {
             try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
             try audioSession.setActive(true)
         } catch {
             errorLog("Failed to set audio session category: \(error)")
         }
        let speechUtterance = AVSpeechUtterance(string: text)

        // 設定で選ばれた音声（Enhanced/Premium/パーソナルボイス）・速度・ピッチを適用
        VoiceResolver.configure(speechUtterance)

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
            warningLog("Cannot speak: text is empty")
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
         do {
             try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
             try audioSession.setActive(true)
         } catch {
             errorLog("Failed to set audio session category: \(error)")
         }

        let speechUtterance = AVSpeechUtterance(string: text)

        // 設定で選ばれた音声（Enhanced/Premium/パーソナルボイス）・速度・ピッチを適用
        VoiceResolver.configure(speechUtterance)

        viewStore.send(.startSpeaking)
        // ミニプレイヤー用にnowPlayingも更新
        let title = String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        viewStore.send(.nowPlaying(.startPlaying(title: title, text: text, source: .textInput(fileId: nil, text: text))))

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
                errorLog("Speech synthesis failed: \(error)")
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
