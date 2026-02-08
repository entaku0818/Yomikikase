//
//  TTSInfoSheet.swift
//  VoiceYourText
//
//  Created by Claude on 2026/02/08.
//

import SwiftUI

struct TTSInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let useCloudTTS: Bool
    let cloudTTSAvailable: Bool
    let speechRate: Float
    let speechPitch: Float
    let selectedVoice: VoiceConfig?

    var body: some View {
        NavigationStack {
            List {
                Section("再生方式") {
                    HStack {
                        Image(systemName: useCloudTTS ? "cloud.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(useCloudTTS ? "高音質TTS" : "基本TTS")
                                .font(.headline)
                            Text(useCloudTTS ? "高品質な音声で再生" : "デバイスの標準音声で再生")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if useCloudTTS && cloudTTSAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                if useCloudTTS {
                    Section("音声情報") {
                        if let voice = selectedVoice {
                            HStack {
                                Text("音声")
                                Spacer()
                                Text(voice.name)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("言語")
                                Spacer()
                                Text(voice.language)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text("音声")
                                Spacer()
                                Text("デフォルト")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TTS方式について")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("高音質TTS: 高品質な音声で再生できますが、保存時に音声生成が必要です。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("基本TTS: デバイスの標準音声で即座に再生できます。保存は不要です。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("※ TTS方式を変更するには、編集画面から再保存してください。")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("TTS情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TTSInfoSheet(
        useCloudTTS: true,
        cloudTTSAvailable: true,
        speechRate: 0.5,
        speechPitch: 1.0,
        selectedVoice: VoiceConfig(
            id: "ja-jp-female-a",
            name: "日本語（女性）",
            language: "日本語",
            gender: "female",
            description: "日本語の女性音声"
        )
    )
}

#Preview("Basic TTS") {
    TTSInfoSheet(
        useCloudTTS: false,
        cloudTTSAvailable: false,
        speechRate: 0.75,
        speechPitch: 1.2,
        selectedVoice: nil as VoiceConfig?
    )
}
