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
                    .background(isTextEmpty && !isSpeaking ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(isTextEmpty && !isSpeaking)

            // スピード表示
            Button(action: onSpeedTap) {
                Text(SpeechSettings.formatSpeed(speechRate))
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
            onSpeedTap: {}
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
            onSpeedTap: {}
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
            onSpeedTap: {}
        )
    }
}
