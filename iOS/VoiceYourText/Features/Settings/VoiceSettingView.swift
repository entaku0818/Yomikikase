import SwiftUI
import ComposableArchitecture
import AVFoundation

@ViewAction(for: SettingsReducer.self)
struct VoiceSettingView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.scenePhase) private var scenePhase
    /// 設定アプリから戻ったときに音声一覧を引き直すためのトークン。
    /// `availableVoices` は `AVSpeechSynthesisVoice.speechVoices()` を読む computed property だが、
    /// 高品質音声をダウンロードして戻ってきても SwiftUI 側の状態は何も変わらないため再描画されず、
    /// 「落としてきたのに一覧に出てこない」ように見えてしまう。復帰時にこれを変えて再評価させる。
    @State private var voiceListRefreshToken = 0

    private var selectedLanguageCode: String {
        UserDefaultsManager.shared.languageSetting ?? "ja"
    }

    private var availableVoices: [AVSpeechSynthesisVoice] {
        _ = voiceListRefreshToken // 復帰時に再評価させるための依存
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: selectedLanguageCode) }
            .filter {
                if #available(iOS 17.0, *) {
                    return !$0.voiceTraits.contains(.isPersonalVoice)
                }
                return true
            }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    /// 高品質音声の状態（使用中 / 未選択 / 未ダウンロード）。
    /// 音声を選び直したら再判定できるよう selectedVoiceIdentifier を入力にする。
    private var voiceQualityStatus: VoiceQualityStatus {
        _ = voiceListRefreshToken // 復帰時に再判定させるための依存
        return VoiceQualityStatus.current(
            languageCode: selectedLanguageCode,
            selectedIdentifier: store.selectedVoiceIdentifier
        )
    }

    var body: some View {
        Form {
            Section {
                HighQualityVoicePrompt(
                    status: voiceQualityStatus,
                    languageCode: selectedLanguageCode
                )
            }

            Section(header: Text("利用可能な音声")) {
                if availableVoices.isEmpty {
                    Text("選択された言語の音声が見つかりません")
                        .foregroundColor(.gray)
                } else {
                    ForEach(availableVoices, id: \.identifier) { voice in
                        VoiceSettingRow(
                            voice: voice,
                            isSelected: voice.identifier == store.selectedVoiceIdentifier,
                            onTap: { selectAndPreview(voice) }
                        )
                    }
                }
            }

            PersonalVoiceSection(
                languageCode: selectedLanguageCode,
                selectedVoiceIdentifier: store.selectedVoiceIdentifier,
                speechRate: store.speechRate,
                speechPitch: store.speechPitch,
                onSelect: { send(.setVoiceIdentifier($0)) }
            )

            if selectedLanguageCode.starts(with: "en") || selectedLanguageCode.starts(with: "ja") {
                KokoroTTSSection(
                    kokoroEnabled: store.kokoroEnabled,
                    kokoroVoice: store.kokoroVoice,
                    isJapanese: selectedLanguageCode.starts(with: "ja"),
                    onToggle: { send(.setKokoroEnabled($0)) },
                    onSelectVoice: { send(.setKokoroVoice($0)) }
                )
            }
        }
        .onAppear {
            if UserDefaultsManager.shared.languageSetting == nil {
                UserDefaultsManager.shared.languageSetting = "ja"
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 設定アプリで高品質音声を落として戻ってきたケースを拾う
            if newPhase == .active {
                voiceListRefreshToken += 1
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func selectAndPreview(_ voice: AVSpeechSynthesisVoice) {
        send(.setVoiceIdentifier(voice.identifier))
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: previewText())
        utterance.voice = voice
        utterance.rate = store.speechRate
        utterance.pitchMultiplier = store.speechPitch
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }

    private func previewText() -> String {
        switch selectedLanguageCode {
        case "ja": return "こんにちは、これはテストです。"
        case "en": return "Hello, this is a test."
        case "de": return "Hallo, das ist ein Test."
        case "es": return "Hola, esto es una prueba."
        case "fr": return "Bonjour, ceci est un test."
        default: return "Hello, this is a test."
        }
    }
}

// MARK: - Personal Voice Section

/// パーソナルボイスの認可・選択。
/// 選択された identifier は通常の再生経路（VoiceResolver）からも使われる。
private struct PersonalVoiceSection: View {
    let languageCode: String
    let selectedVoiceIdentifier: String?
    let speechRate: Float
    let speechPitch: Float
    let onSelect: (String) -> Void

    @State private var authStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined

    /// 現在の読み上げ言語と一致するパーソナルボイスだけを出す。
    /// 日本語の文章を英語のパーソナルボイスで読ませても実用にならないため。
    private var personalVoices: [AVSpeechSynthesisVoice] {
        PersonalVoiceAccess.availableVoices()
            .filter { VoiceResolver.languagesMatch($0.language, languageCode) }
    }

    /// 言語が一致しないパーソナルボイスしか無い場合の件数（説明文に使う）。
    private var otherLanguageVoiceCount: Int {
        PersonalVoiceAccess.availableVoices().count - personalVoices.count
    }

    var body: some View {
        Section(header: Text("パーソナルボイス")) {
            switch authStatus {
            case .notDetermined:
                Button("パーソナルボイスを使用する") {
                    PersonalVoiceAccess.request { authStatus = $0 }
                }
            case .denied:
                Label("設定でアクセスを許可してください", systemImage: "xmark.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
            case .unsupported:
                Label("このデバイスは未対応です", systemImage: "exclamationmark.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
            case .authorized:
                if personalVoices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if otherLanguageVoiceCount > 0 {
                            Text("現在の読み上げ言語に対応したパーソナルボイスがありません")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            Text("パーソナルボイスが作成されていません")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Text("設定 > アクセシビリティ > パーソナルボイス で作成できます（現在は英語のみ対応）")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                } else {
                    ForEach(personalVoices, id: \.identifier) { voice in
                        VoiceSettingRow(
                            voice: voice,
                            isSelected: voice.identifier == selectedVoiceIdentifier,
                            onTap: {
                                onSelect(voice.identifier)
                                previewVoice(voice)
                            }
                        )
                    }
                    Text("選んだパーソナルボイスは、アプリ内の読み上げでもそのまま使われます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            @unknown default:
                EmptyView()
            }
        }
        .onAppear {
            authStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        }
    }

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        let synthesizer = AVSpeechSynthesizer()
        let sample = languageCode.hasPrefix("ja") ? "こんにちは、これはテストです。" : "Hello, this is a test."
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = voice
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }
}

// MARK: - Voice Row

private struct VoiceSettingRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Text(voice.language)
                            .font(.caption)
                            .foregroundColor(.gray)
                        qualityBadge
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    /// 音質バッジ。ラベルは VoiceResolver 側の定義と共有する。
    @ViewBuilder
    private var qualityBadge: some View {
        if let label = voice.quality.displayLabel {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .cornerRadius(4)
        }
    }

    private var badgeColor: Color {
        voice.quality == .premium ? .purple : .blue
    }
}
