//
//  MiniPlayerView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/12/29.
//

import ComposableArchitecture
import SwiftUI

struct MiniPlayerView: View {
    let store: StoreOf<NowPlayingFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            HStack(spacing: 12) {
                // スピーカーアイコン（再生中のみアニメーション）
                Image(systemName: viewStore.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: viewStore.isPlaying)

                // タイトル
                Text(viewStore.currentTitle)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // スリープタイマー（残り時間の表示 & 設定メニュー）
                SleepTimerMenu(sleepTimer: viewStore.sleepTimer) {
                    viewStore.send(.setSleepTimer($0))
                }

                // 再生/一時停止ボタン
                PlayPauseButton(isPlaying: viewStore.isPlaying) {
                    viewStore.send(viewStore.isPlaying ? .stopPlaying : .resumePlaying)
                }

                // 閉じるボタン
                CloseButton {
                    viewStore.send(.dismiss)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                viewStore.send(.navigateToSource)
            }
        }
    }
}

private struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.primary)
                .frame(width: 44, height: 44)
        }
    }
}

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 44, height: 44)
        }
    }
}

/// スリープタイマーの残り時間表示と設定メニュー。
private struct SleepTimerMenu: View {
    let sleepTimer: SleepTimerState?
    let onSelect: (SleepTimerOption?) -> Void

    var body: some View {
        Menu {
            ForEach(SleepTimerOption.presets) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option.title)
                }
            }
            if sleepTimer != nil {
                Divider()
                Button(role: .destructive) {
                    onSelect(nil)
                } label: {
                    Text("タイマーを解除")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sleepTimer == nil ? "moon" : "moon.fill")
                    .font(.system(size: 16))
                if let sleepTimer {
                    Text(sleepTimer.displayText)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }
            }
            .foregroundColor(sleepTimer == nil ? .secondary : AppTheme.primary)
            .frame(minHeight: 44)
        }
        .accessibilityLabel(Text("スリープタイマー"))
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView(
            store: Store(
                initialState: NowPlayingFeature.State(
                    isPlaying: true,
                    currentTitle: "サンプルテキストの読み上げ",
                    currentText: "これはサンプルテキストです。",
                    progress: 0.35,
                    source: .textInput(fileId: nil, text: "これはサンプルテキストです。")
                )
            ) {
                NowPlayingFeature()
            }
        )
    }
    .background(Color.gray.opacity(0.2))
}
