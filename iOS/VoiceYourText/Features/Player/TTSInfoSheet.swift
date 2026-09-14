//
//  TTSInfoSheet.swift
//  VoiceYourText
//
//  Created by Claude on 2026/02/08.
//

import SwiftUI

struct TTSInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// 撤去前のクラウドTTSで生成され、端末に残っている音声ファイルで再生するかどうか。
    let hasGeneratedAudio: Bool
    let speechRate: Float
    let speechPitch: Float

    /// 端末TTSで実際に使われる音声の品質状態。
    private var deviceVoiceStatus: VoiceQualityStatus { .current() }

    var body: some View {
        NavigationStack {
            List {
                Section("再生方式") {
                    HStack {
                        Image(systemName: hasGeneratedAudio ? "waveform" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(hasGeneratedAudio ? "保存済み音声" : "端末TTS")
                                .font(.headline)
                            Text(hasGeneratedAudio
                                 ? "以前に生成した音声ファイルで再生"
                                 : "デバイスの音声で再生")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }

                // 端末TTSで読むときだけ、高品質音声の状態と誘導を出す。
                // 設定画面まで行かないと気づけなかったダウンロード導線を再生画面からも辿れるようにする。
                if !hasGeneratedAudio {
                    Section("読み上げ音声") {
                        HighQualityVoicePrompt(status: deviceVoiceStatus)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("読み上げについて")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("端末TTS: デバイスの音声で、インターネットに接続せず即座に再生します。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if hasGeneratedAudio {
                            Text("保存済み音声: 以前に生成した音声ファイルをそのまま再生します。編集して保存し直すと端末TTSに切り替わります。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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

#Preview("保存済み音声") {
    TTSInfoSheet(
        hasGeneratedAudio: true,
        speechRate: 0.5,
        speechPitch: 1.0
    )
}

#Preview("端末TTS") {
    TTSInfoSheet(
        hasGeneratedAudio: false,
        speechRate: 0.75,
        speechPitch: 1.2
    )
}
