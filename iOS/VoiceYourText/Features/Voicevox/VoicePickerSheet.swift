import SwiftUI
import ComposableArchitecture

/// 再生画面のプレイヤーの上に出す「今の声」の行。押すと声の一覧（VoicePickerSheet）を開く。
struct VoicePickerRow: View {
    let store: StoreOf<VoicevoxSettingsFeature>
    let onTap: () -> Void

    private var voiceName: String {
        store.isEnabled
            ? VoicevoxCatalog.voice(for: store.selectedSpeakerId).character
            : String(localized: "端末の音声")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: store.isEnabled ? "person.wave.2.fill" : "iphone")
                Text(voiceName)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                if store.isEnabled, let usage = store.usage {
                    Text("残り \(usage.remaining.formatted())字")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.primarySoft)
            .clipShape(Capsule())
        }
        .accessibilityLabel(Text("声を選ぶ"))
        .accessibilityValue(Text(voiceName))
    }
}

/// 再生画面から開く声の一覧。端末の音声とキャラ音声6声から選べる。キャラは選ぶと試聴する。
@ViewAction(for: VoicevoxSettingsFeature.self)
struct VoicePickerSheet: View {
    @Bindable var store: StoreOf<VoicevoxSettingsFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        send(.enabledChanged(false))
                    } label: {
                        row(title: String(localized: "端末の音声"), subtitle: String(localized: "設定で選んだ端末の声・Kokoro AI音声"),
                            isSelected: !store.isEnabled, isLoading: false)
                    }
                }

                Section {
                    ForEach(store.voices) { voice in
                        Button {
                            send(.voiceTapped(voice.speakerId))
                        } label: {
                            row(title: voice.character, subtitle: voice.style,
                                isSelected: store.isEnabled && store.selectedSpeakerId == voice.speakerId,
                                isLoading: store.previewingSpeakerId == voice.speakerId)
                        }
                    }
                } header: {
                    Text("キャラ音声（VOICEVOX）")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let usage = store.usage {
                            Text("今月の残り \(usage.remaining.formatted()) / \(usage.limit.formatted())字")
                        } else if store.isUsageUnavailable {
                            Text("残り文字数を取得できませんでした")
                        }
                        Text("選ぶと試聴します。選んだ声は次の再生から使われます。")
                        if let usage = store.usage, !usage.isPremium {
                            Button {
                                send(.upgradeTapped)
                            } label: {
                                Text("プレミアムなら月20万字まで")
                            }
                        }
                    }
                }
            }
            .navigationTitle("声を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $store.showPaywall) {
            SubscriptionView(source: "voicevox_picker")
        }
    }

    private func row(title: String, subtitle: String, isSelected: Bool, isLoading: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLoading {
                ProgressView()
            } else if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .contentShape(Rectangle())
    }
}
