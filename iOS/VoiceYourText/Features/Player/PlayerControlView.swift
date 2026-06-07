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
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 50, height: 40)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
            }

            // 再生/停止ボタン（中央・アクセント丸66pt）
            Button(action: {
                if isSpeaking {
                    onStop()
                } else {
                    onPlay()
                }
            }) {
                Image(systemName: isSpeaking ? "stop.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.onPrimary)
                    .frame(width: 66, height: 66)
                    .background(isTextEmpty && !isSpeaking ? Color.gray : AppTheme.primary)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.primary.opacity(isTextEmpty && !isSpeaking ? 0 : 0.25), radius: 8, x: 0, y: 4)
            }
            .disabled(isTextEmpty && !isSpeaking)

            // スピード表示（右端・アクセントの丸ピル）
            HStack {
                Spacer()
                Button(action: onSpeedTap) {
                    Text(SpeechSettings.formatSpeed(speechRate))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                        .frame(minWidth: 50)
                        .frame(height: 36)
                        .padding(.horizontal, 8)
                        .background(AppTheme.primarySoft)
                        .clipShape(Capsule())
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
