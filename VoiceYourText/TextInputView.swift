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
    @State private var title: String = ""
    @State private var showingSaveAlert = false
    @Dependency(\.speechSynthesizer) var speechSynthesizer
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // タイトル入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("タイトル（オプション）")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("タイトルを入力", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // テキスト入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("読み上げるテキスト")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $text)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // 操作ボタン
                HStack(spacing: 16) {
                    Button(action: {
                        speak()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("読み上げ開始")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(text.isEmpty)
                    
                    Button(action: {
                        stopSpeaking()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("停止")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 保存ボタン
                Button(action: {
                    showingSaveAlert = true
                }) {
                    Text("保存する")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(text.isEmpty)
                
                if !UserDefaultsManager.shared.isPremiumUser {
                    AdmobBannerView()
                        .frame(height: 50)
                }
            }
            .navigationTitle("テキスト読み上げ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
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
            } catch {
                print("❌ Speech synthesis failed: \(error)")
            }
        }
    }
    
    private func stopSpeaking() {
        print("🛑 TextInputView: Stopping speech synthesis")
        Task {
            _ = await speechSynthesizer.stopSpeaking()
            print("✅ Speech synthesis stopped")
        }
    }
    
    private func saveText() {
        let finalTitle = title.isEmpty ? String(text.prefix(20)) : title
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
        
        SpeechTextRepository.shared.insert(
            title: finalTitle,
            text: text,
            languageSetting: languageSetting
        )
    }
}

#Preview {
    TextInputView(store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
        Speeches()
    })
}