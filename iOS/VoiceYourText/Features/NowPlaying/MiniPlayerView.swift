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
            VStack(spacing: 8) {
                // 上部: タイトルとコントロール
                HStack(spacing: 12) {
                    // スピーカーアイコン（再生中のみアニメーション）
                    Image(systemName: viewStore.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: viewStore.isPlaying)

                    // タイトル
                    Text(viewStore.currentTitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    // 再生/停止ボタン
                    Button {
                        if viewStore.isPlaying {
                            viewStore.send(.stopPlaying)
                        } else {
                            viewStore.send(.resumePlaying)
                        }
                    } label: {
                        Image(systemName: viewStore.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }

                    // 閉じるボタン
                    Button {
                        viewStore.send(.dismiss)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 下部: プログレスバー（再生中のみ表示）
                if viewStore.isPlaying {
                    ProgressView(value: viewStore.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                } else {
                    Spacer()
                        .frame(height: 12)
                }
            }
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
