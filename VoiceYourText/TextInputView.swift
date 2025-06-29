//
//  TextInputView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

struct TextInputView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    @State private var text: String = ""
    @State private var title: String = ""
    @State private var showingSaveAlert = false
    
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
        // 音声合成の実装は既存のSpeechViewから移植
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        let speechUtterance = AVSpeechUtterance(string: text)
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75
        
        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(speechUtterance)
    }
    
    private func stopSpeaking() {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.stopSpeaking(at: .immediate)
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