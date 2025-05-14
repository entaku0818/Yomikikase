import SwiftUI
import ComposableArchitecture
import AVFoundation

struct VoiceSettingView: View {
    let store: Store<SettingsReducer.State, SettingsReducer.Action>
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Form {
                Section(header: Text("利用可能な音声")) {
                    let voices = AVSpeechSynthesisVoice.speechVoices()
                        .filter { voice in
                            // 選択されている言語の音声のみをフィルタリング
                            if let languageCode = UserDefaultsManager.shared.languageSetting {
                                return voice.language.starts(with: languageCode)
                            }
                            return false
                        }
                    
                    if voices.isEmpty {
                        Text("選択された言語の音声が見つかりません")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(voices, id: \.identifier) { voice in
                            Button(action: {
                                viewStore.send(.setVoiceIdentifier(voice.identifier))
                                // 音声プレビューを試行
                                do {
                                    let synthesizer = AVSpeechSynthesizer()
                                    let utterance = AVSpeechUtterance(string: "こんにちは、これはテストです。")
                                    utterance.voice = voice
                                    utterance.rate = viewStore.speechRate
                                    utterance.pitchMultiplier = viewStore.speechPitch
                                    
                                    // 音声合成が利用可能かチェック
                                    if synthesizer.isSpeaking {
                                        synthesizer.stopSpeaking(at: .immediate)
                                    }
                                    
                                    synthesizer.speak(utterance)
                                } catch {
                                    showError = true
                                    errorMessage = "音声の再生に失敗しました。シミュレータでは音声が再生できない場合があります。"
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(voice.name)
                                            .font(.body)
                                        Text(voice.language)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if voice.identifier == viewStore.selectedVoiceIdentifier {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("音声の調整")) {
                    HStack {
                        Image(systemName: "tortoise.fill")
                        Slider(value: viewStore.binding(
                            get: \.speechRate,
                            send: SettingsReducer.Action.setSpeechRate
                        ), in: 0.0...2.0, step: 0.1)
                        Image(systemName: "hare.fill")
                    }

                    HStack {
                        Image(systemName: "speaker.wave.1")
                        Slider(value: viewStore.binding(
                            get: \.speechPitch,
                            send: SettingsReducer.Action.setSpeechPitch
                        ), in: 0.5...2.0, step: 0.1)
                        Image(systemName: "speaker.wave.3")
                    }
                }
            }
            .onAppear {
                // 言語が選択されていない場合、デフォルトで英語を設定
                if UserDefaultsManager.shared.languageSetting == nil {
                    UserDefaultsManager.shared.languageSetting = "en"
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
} 