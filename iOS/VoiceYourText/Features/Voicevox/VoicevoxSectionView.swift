import SwiftUI
import ComposableArchitecture

/// 音声設定画面の「キャラ音声（VOICEVOX）」セクション。日本語の文章でだけ表示する。
@ViewAction(for: VoicevoxSettingsFeature.self)
struct VoicevoxSection: View {
    @Bindable var store: StoreOf<VoicevoxSettingsFeature>

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { store.isEnabled }, set: { send(.enabledChanged($0)) })) {
                HStack(spacing: 10) {
                    Image(systemName: "person.wave.2.fill")
                        .foregroundStyle(AppTheme.primary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("キャラ音声（VOICEVOX）")
                            .font(.headline)
                        Text("人の声に近いキャラクターの声で読み上げます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            if store.isEnabled {
                ForEach(store.voices) { voice in
                    Button {
                        send(.voiceTapped(voice.speakerId))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.character)
                                    .foregroundStyle(.primary)
                                Text(voice.style)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.previewingSpeakerId == voice.speakerId {
                                ProgressView()
                            } else if store.selectedSpeakerId == voice.speakerId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint(Text("選ぶと試聴します"))
                }

                usageRow
            }
        } header: {
            Text("キャラ音声")
        } footer: {
            if store.isEnabled {
                Text("インターネット接続が必要です。オンにすると Kokoro AI音声より優先されます。一度聴いた文は端末に保存され、聴き直しでは文字数を使いません。")
            }
        }
        .onAppear { send(.onAppear) }
        .sheet(isPresented: $store.showPaywall) {
            SubscriptionView(source: "voicevox_settings")
        }
    }

    @ViewBuilder
    private var usageRow: some View {
        if let usage = store.usage {
            VStack(alignment: .leading, spacing: 6) {
                Text("今月の残り \(usage.remaining.formatted()) / \(usage.limit.formatted())字")
                    .font(.subheadline)
                ProgressView(value: Double(usage.used), total: Double(max(usage.limit, 1)))
                    .tint(AppTheme.primary)
                Text("\(usage.resetAt.formatted(.dateTime.month().day()))にリセット")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !usage.isPremium {
                    Button {
                        send(.upgradeTapped)
                    } label: {
                        Text("プレミアムなら月20万字まで")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        } else if store.isUsageUnavailable {
            Text("残り文字数を取得できませんでした")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
