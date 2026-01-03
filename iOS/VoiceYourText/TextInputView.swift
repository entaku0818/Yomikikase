//
//  TextInputView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
import Dependencies

struct TextInputView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    @State private var text: String = ""
    @State private var isEditMode: Bool = true
    @State private var isSpeaking = false
    @State private var highlightedRange: NSRange? = nil
    @State private var showingSpeedPicker = false
    @FocusState private var isTextEditorFocused: Bool
    @Dependency(\.speechSynthesizer) var speechSynthesizer

    let initialText: String
    let fileId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
                    // 再生中でも止めずにdismiss（ミニプレイヤーで継続）
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .padding(.leading, 8)

                Spacer()

                if isEditMode {
                    Button("保存") {
                        saveText()
                        isEditMode = false
                    }
                    .disabled(text.isEmpty)
                    .padding(.trailing, 16)
                }
            }
            .frame(height: 56)
            .background(Color(UIColor.systemBackground))

            Divider()

            // メインコンテンツ
            if isEditMode {
                // 編集モード
                editModeContent
            } else {
                // プレイヤーモード
                playerModeContent
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            text = initialText
            // 既存ファイルを開いた場合はプレイヤーモードで開始
            if fileId != nil && !initialText.isEmpty {
                isEditMode = false
            } else if initialText.isEmpty {
                // 新規作成時はキーボードを自動表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextEditorFocused = true
                }
            }

            // nowPlayingと同期（ミニプレイヤーから戻ってきた場合）
            let nowPlaying = store.withState { $0.nowPlaying }
            if nowPlaying.isPlaying {
                if case .textInput(let sourceFileId, _) = nowPlaying.source {
                    if sourceFileId == fileId {
                        isSpeaking = true
                        isEditMode = false
                    }
                }
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
    }

    // MARK: - 編集モード
    private var editModeContent: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 20))
                .padding(.horizontal)
                .padding(.top, 8)
                .focused($isTextEditorFocused)

            // プレースホルダー
            if text.isEmpty {
                Text("読み上げたいテキストを入力してください...")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - プレイヤーモード
    private var playerModeContent: some View {
        VStack(spacing: 0) {
            // テキスト表示（読み取り専用）
            // UITextViewは自身でスクロールするため、外側のScrollViewは不要
            HighlightableTextView(
                text: .constant(text),
                highlightedRange: $highlightedRange,
                isEditable: false,
                fontSize: 20
            )
            .padding(.horizontal)
            .padding(.top, 16)

            // 広告バナー
            if !UserDefaultsManager.shared.isPremiumUser {
                AdmobBannerView()
                    .frame(height: 50)
            }

            // プレイヤーコントロール
            PlayerControlView(
                isSpeaking: isSpeaking,
                isTextEmpty: text.isEmpty,
                speechRate: UserDefaultsManager.shared.speechRate,
                onPlay: {
                    speakWithHighlight()
                },
                onStop: {
                    stopSpeaking()
                },
                onSpeedTap: {
                    showingSpeedPicker = true
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func speakWithHighlight() {
        guard !text.isEmpty else {
            print("❌ TextInputView: Cannot speak - text is empty")
            return
        }

        isSpeaking = true

        // nowPlayingを更新（ミニプレイヤー用）
        let title = String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        store.send(.nowPlaying(.startPlaying(title: title, text: text, source: .textInput(fileId: fileId, text: text))))

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to set audio session category: \(error)")
            return
        }

        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75

        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume

        Task {
            do {
                try await speechSynthesizer.speakWithHighlight(
                    speechUtterance,
                    { range, _ in
                        DispatchQueue.main.async {
                            highlightedRange = range
                        }
                    },
                    {
                        DispatchQueue.main.async {
                            isSpeaking = false
                            highlightedRange = nil
                            // 読み上げ完了時はnowPlayingを停止（コンテンツは保持）
                            store.send(.nowPlaying(.stopPlaying))
                        }
                    }
                )
            } catch {
                print("❌ Speech synthesis failed: \(error)")
                DispatchQueue.main.async {
                    isSpeaking = false
                    highlightedRange = nil
                    store.send(.nowPlaying(.stopPlaying))
                }
            }
        }
    }

    private func stopSpeaking() {
        isSpeaking = false
        highlightedRange = nil
        store.send(.nowPlaying(.stopPlaying))
    }

    private func saveText() {
        let finalTitle = String(text.prefix(20))
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english

        if let fileId = fileId {
            SpeechTextRepository.shared.updateSpeechText(
                id: fileId,
                title: finalTitle,
                text: text
            )
        } else {
            SpeechTextRepository.shared.insert(
                title: finalTitle,
                text: text,
                languageSetting: languageSetting
            )
        }
    }
}

#Preview("Edit Mode") {
    TextInputView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        initialText: "",
        fileId: nil
    )
}

#Preview("Player Mode") {
    TextInputView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        initialText: "これはサンプルテキストです。読み上げのテストを行います。",
        fileId: UUID()
    )
}
