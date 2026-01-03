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
    let currentTime: TimeInterval
    let totalTime: TimeInterval
    let speechRate: Float
    let onPlay: () -> Void
    let onStop: () -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    let onSpeedTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // プログレスバーと時間表示
            VStack(spacing: 4) {
                ProgressView(value: totalTime > 0 ? currentTime / totalTime : 0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(totalTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)

            // コントロールボタン
            HStack(spacing: 0) {
                // 10秒戻る
                Button(action: onSkipBackward) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 60)
                }
                .disabled(!isSpeaking)

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

                Spacer()

                // 10秒進む
                Button(action: onSkipForward) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 60)
                }
                .disabled(!isSpeaking)

                // スピード表示
                Button(action: onSpeedTap) {
                    Text(formatSpeed(speechRate))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 40)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
            currentTime: 9,
            totalTime: 49,
            speechRate: 0.5,
            onPlay: {},
            onStop: {},
            onSkipBackward: {},
            onSkipForward: {},
            onSpeedTap: {}
        )
    }
}

#Preview("Playing") {
    VStack {
        Spacer()
        PlayerControlView(
            isSpeaking: true,
            currentTime: 25,
            totalTime: 49,
            speechRate: 0.75,
            onPlay: {},
            onStop: {},
            onSkipBackward: {},
            onSkipForward: {},
            onSpeedTap: {}
        )
    }
}
