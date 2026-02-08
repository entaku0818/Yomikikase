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
    let isTextEmpty: Bool
    let speechRate: Float
    let onPlay: () -> Void
    let onStop: () -> Void
    let onSpeedTap: () -> Void
    let onTTSInfoTap: (() -> Void)?

    var body: some View {
        ZStack {
            // TTS情報ボタン（左端）
            if let onTTSInfoTap = onTTSInfoTap {
                HStack {
                    Button(action: onTTSInfoTap) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 40)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
            }

            // 再生/停止ボタン（中央）
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
                    .background(isTextEmpty && !isSpeaking ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(isTextEmpty && !isSpeaking)

            // スピード表示（右端）
            HStack {
                Spacer()
                Button(action: onSpeedTap) {
                    Text(SpeechSettings.formatSpeed(speechRate))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 40)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack {
        Spacer()
        PlayerControlView(
            isSpeaking: false,
            isTextEmpty: false,
            speechRate: 0.5,
            onPlay: {},
            onStop: {},
            onSpeedTap: {},
            onTTSInfoTap: {}
        )
    }
}

#Preview("Playing") {
    VStack {
        Spacer()
        PlayerControlView(
            isSpeaking: true,
            isTextEmpty: false,
            speechRate: 0.75,
            onPlay: {},
            onStop: {},
            onSpeedTap: {},
            onTTSInfoTap: {}
        )
    }
}

#Preview("Disabled") {
    VStack {
        Spacer()
        PlayerControlView(
            isSpeaking: false,
            isTextEmpty: true,
            speechRate: 0.5,
            onPlay: {},
            onStop: {},
            onSpeedTap: {},
            onTTSInfoTap: nil
        )
    }
}
