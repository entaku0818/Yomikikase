//
//  PlayerControlView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/01/03.
//

import AVFoundation
import SwiftUI

struct PlayerControlView: View {
    let isSpeaking: Bool
    let speechRate: Float
    let onPlay: () -> Void
    let onStop: () -> Void
    let onSpeedTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Spacer()

            // 再生/停止ボタン（大きな青い丸）
            Button(action: {
                if isSpeaking {
                    onStop()
                } else {
                    onPlay()
                }
            }) {
                Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.blue)
                    .clipShape(Circle())
            }

            // スピード表示
            Button(action: onSpeedTap) {
                Text(formatSpeed(speechRate))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 40)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    private func formatSpeed(_ rate: Float) -> String {
        // AVSpeechUtteranceのrateは0.0-1.0の範囲
        // デフォルトは0.5、最大は1.0
        // 表示用に倍率に変換 (0.5 = 1.0x, 1.0 = 2.0x)
        let displayRate = rate / AVSpeechUtteranceDefaultSpeechRate
        if displayRate == 1.0 {
            return "1x"
        } else if displayRate == floor(displayRate) {
            return String(format: "%.0fx", displayRate)
        } else {
            return String(format: "%.1fx", displayRate)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        PlayerControlView(
            isSpeaking: false,
            speechRate: 0.5,
            onPlay: {},
            onStop: {},
            onSpeedTap: {}
        )
    }
}

#Preview("Playing") {
    VStack {
        Spacer()
        PlayerControlView(
            isSpeaking: true,
            speechRate: 0.75,
            onPlay: {},
            onStop: {},
            onSpeedTap: {}
        )
    }
}
