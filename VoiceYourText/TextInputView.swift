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
    @State private var showingSaveAlert = false
    @State private var isSpeaking = false
    @State private var highlightedRange: NSRange? = nil
    @FocusState private var isTextEditorFocused: Bool
    @Dependency(\.speechSynthesizer) var speechSynthesizer
    
    let initialText: String
    let fileId: UUID?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // フルスクリーンのテキストエディタ
                ZStack(alignment: .topLeading) {
                    HighlightableTextView(
                        text: $text,
                        highlightedRange: $highlightedRange,
                        isEditable: true,
                        fontSize: 20
                    )
                    .padding(.horizontal)
                    .padding(.top, 60)
                    .background(Color(UIColor.systemBackground))
                    
                    // プレースホルダー
                    if text.isEmpty {
                        Text("読み上げたいテキストを入力してください...")
                            .foregroundColor(.secondary)
                            .font(.system(size: 20))
                            .padding(.horizontal)
                            .padding(.top, 70)
                            .allowsHitTesting(false)
                    }
                }
                
                // フローティング再生ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            if isSpeaking {
                                stopSpeaking()
                            } else {
                                speakWithHighlight()
                            }
                        }) {
                            Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(isSpeaking ? Color.red : Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .disabled(text.isEmpty)
                        .padding(.trailing, 24)
                        .padding(.bottom, UserDefaultsManager.shared.isPremiumUser ? 24 : 80)
                    }
                }
                
                // 広告バナー（最下部）
                if !UserDefaultsManager.shared.isPremiumUser {
                    VStack {
                        Spacer()
                        AdmobBannerView()
                            .frame(height: 50)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                HStack {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    Button("保存") {
                        showingSaveAlert = true
                    }
                    .disabled(text.isEmpty)
                    .padding(.trailing, 16)
                }
                .padding(.top, 8)
            }
            .onAppear {
                // 初期テキストを設定
                text = initialText
                // 画面表示時にキーボードを自動表示（新規作成時のみ）
                if initialText.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextEditorFocused = true
                    }
                }
            }
            .alert("保存", isPresented: $showingSaveAlert) {
                Button("保存") {
                    saveText()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("このテキストを保存しますか？")
            }
        }
    }
    
    private func speak() {
        guard !text.isEmpty else { 
            print("❌ TextInputView: Cannot speak - text is empty")
            return 
        }
        
        isSpeaking = true
        print("🎤 TextInputView: Starting speech synthesis")
        print("📝 Text to speak: \(text)")
        
        // 音声セッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to set audio session category: \(error)")
            return
        }
        
        // 音声設定の取得
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75
        
        print("🌐 Language: \(language)")
        print("⚡ Rate: \(rate), Pitch: \(pitch), Volume: \(volume)")
        
        // 音声合成の設定
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume
        
        // 利用可能な音声確認
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        print("🎵 Available voices for \(language): \(availableVoices.filter { $0.language == language }.count)")
        
        if let selectedVoice = speechUtterance.voice {
            print("✅ Selected voice: \(selectedVoice.name) (\(selectedVoice.language))")
        } else {
            print("⚠️ No voice selected, using default")
        }
        
        // 音声合成開始
        Task {
            do {
                print("🚀 Starting speech synthesis...")
                try await speechSynthesizer.speak(speechUtterance)
                print("✅ Speech synthesis completed")
                isSpeaking = false
            } catch {
                print("❌ Speech synthesis failed: \(error)")
                isSpeaking = false
            }
        }
    }
    
    private func speakWithHighlight() {
        guard !text.isEmpty else { 
            print("❌ TextInputView: Cannot speak - text is empty")
            return 
        }
        
        isSpeaking = true
        print("🎤 TextInputView: Starting speech synthesis with highlighting")
        print("📝 Text to speak: \(text)")
        
        // 音声セッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to set audio session category: \(error)")
            return
        }
        
        // 音声設定の取得
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75
        
        print("🌐 Language: \(language)")
        print("⚡ Rate: \(rate), Pitch: \(pitch), Volume: \(volume)")
        
        // 音声合成の設定
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume
        
        // 音声合成開始
        Task {
            do {
                print("🚀 Starting speech synthesis with highlighting...")
                try await speechSynthesizer.speakWithHighlight(
                    speechUtterance,
                    { range, speechString in
                        // ハイライト更新
                        DispatchQueue.main.async {
                            highlightedRange = range
                        }
                    },
                    {
                        // 読み上げ完了
                        DispatchQueue.main.async {
                            print("✅ Speech synthesis completed")
                            isSpeaking = false
                            highlightedRange = nil
                        }
                    }
                )
            } catch {
                print("❌ Speech synthesis failed: \(error)")
                DispatchQueue.main.async {
                    isSpeaking = false
                    highlightedRange = nil
                }
            }
        }
    }

    private func stopSpeaking() {
        print("🛑 TextInputView: Stopping speech synthesis")
        isSpeaking = false
        highlightedRange = nil
        Task {
            _ = await speechSynthesizer.stopSpeaking()
            print("✅ Speech synthesis stopped")
        }
    }
    
    private func saveText() {
        let finalTitle = String(text.prefix(20))
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
        
        if let fileId = fileId {
            // 既存ファイルの更新
            SpeechTextRepository.shared.updateSpeechText(
                id: fileId,
                title: finalTitle,
                text: text
            )
        } else {
            // 新規ファイルの作成
            SpeechTextRepository.shared.insert(
                title: finalTitle,
                text: text,
                languageSetting: languageSetting
            )
        }
    }
}

#Preview {
    TextInputView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        initialText: "",
        fileId: nil
    )
}