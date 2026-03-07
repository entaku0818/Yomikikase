//
//  LanguageSettingView.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2024/02/12.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import AVFAudio
import Dependencies

@ViewAction(for: SettingsReducer.self)
struct LanguageSettingView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    #if DEBUG
    @State private var showScreenshotView = false
    #endif

    var body: some View {
        VStack {
            Form {

                Section(header: Text("プレミアム機能")) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("プレミアムにアップグレード")
                                    .font(.headline)
                                Text("より快適な読み上げ体験を")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }


                        Button(action: {
                            send(.navigateToSubscription)
                        }) {
                            HStack {
                                Text("今すぐアップグレード")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                Section(header: Text("音声設定")) {
                    NavigationLink(destination: VoiceSettingView(store: store)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("音声の選択")
                                Spacer()
                                if let identifier = store.selectedVoiceIdentifier,
                                   let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                                    Text(voice.name)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // 話速の調整
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("声の速さ")
                                    .font(.headline)
                                Spacer()
                                Text(speedLabel(store.speechRate))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            HStack {
                                Image(systemName: "tortoise.fill")
                                    .foregroundColor(.gray)
                                Slider(value: $store.speechRate, in: 0.0...2.0, step: 0.1)
                                Image(systemName: "hare.fill")
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text("遅い")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("標準 1.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("速い")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 声の高さの調整
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("声の高さ")
                                    .font(.headline)
                                Spacer()
                                Text(pitchLabel(store.speechPitch))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            HStack {
                                Image(systemName: "speaker.wave.1.fill")
                                    .foregroundColor(.gray)
                                Slider(value: $store.speechPitch, in: 0.5...2.0, step: 0.1)
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text("低い")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("標準 1.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("高い")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("辞書")) {
                    NavigationLink(destination: UserDictionaryView(
                        store: Store(
                            initialState: UserDictionaryReducer.State()
                        ) {
                            UserDictionaryReducer()
                        }
                    )) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("ユーザー辞書")
                            Spacer()
                        }
                    }
                }

                Section(header: Text("キャッシュ")) {
                    CacheManagementView()
                }

                Section(header: Text("サポート")) {
                    NavigationLink(destination: FeedbackView()) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("お問い合わせ・フィードバック")
                        }
                    }
                }

                Button(action: {
                    send(.resetToDefault)
                }) {
                    Text("読み上げ設定をデフォルト値に戻す")
                        .foregroundColor(.red)
                }

                // デバッグセクション（DEBUGビルドのみ表示）
                #if DEBUG
                Section(header: Text("デバッグ")) {
                    NavigationLink(destination: DebugLogView()) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.red)
                            Text("デバッグログ")
                        }
                    }
                    Button {
                        showScreenshotView = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.purple)
                            Text("スクリーンショット")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
                #endif
            }
            Spacer()
            if !UserDefaultsManager.shared.isPremiumUser {
                AdmobBannerView().frame(width: .infinity, height: 50)
            }
        }
        .navigationBarTitle("設定")
        .onAppear {
            send(.onAppear)
        }
        .navigationDestination(
            isPresented: $store.showSubscriptionView
        ) {
            SubscriptionView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showScreenshotView) {
            ScreenshotView()
        }
        #endif
    }
}

private func speedLabel(_ rate: Float) -> String {
    if abs(rate - 1.0) < 0.05 {
        return "x1.0（標準）"
    }
    return String(format: "x%.1f", rate)
}

private func pitchLabel(_ pitch: Float) -> String {
    if abs(pitch - 1.0) < 0.05 {
        return "x1.0（標準）"
    }
    return String(format: "x%.1f", pitch)
}

struct PremiumFeatureRow: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct CacheManagementView: View {
    @Dependency(\.audioFileManager) var audioFileManager
    @State private var cacheSize: Int64 = 0
    @State private var showClearConfirmation = false
    @State private var isClearing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("音声キャッシュ")
                    Text(formatBytes(cacheSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isClearing {
                    ProgressView()
                } else {
                    Button("クリア") {
                        showClearConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(cacheSize == 0)
                }
            }
        }
        .onAppear {
            updateCacheSize()
        }
        .alert("キャッシュをクリア", isPresented: $showClearConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("クリア", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("ダウンロードした音声ファイルをすべて削除します。")
        }
    }

    private func updateCacheSize() {
        cacheSize = audioFileManager.getCacheSize()
    }

    private func clearCache() {
        isClearing = true
        Task {
            do {
                _ = try audioFileManager.clearCache()
                await MainActor.run {
                    updateCacheSize()
                    isClearing = false
                }
            } catch {
                await MainActor.run {
                    isClearing = false
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
