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
                    // スピーカーアイコン（アニメーション付き）
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .symbolEffect(.variableColor.iterative, options: .repeating)

                    // タイトル
                    Text(viewStore.currentTitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    // 停止ボタン
                    Button {
                        viewStore.send(.stopPlaying)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 下部: プログレスバー
                ProgressView(value: viewStore.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
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
                    source: .textInput
                )
            ) {
                NowPlayingFeature()
            }
        )
    }
    .background(Color.gray.opacity(0.2))
}
