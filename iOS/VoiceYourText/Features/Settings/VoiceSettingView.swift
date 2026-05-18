import SwiftUI
import ComposableArchitecture
import AVFoundation

@ViewAction(for: SettingsReducer.self)
struct VoiceSettingView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @State private var showError = false
    @State private var errorMessage = ""

    private var selectedLanguageCode: String {
        UserDefaultsManager.shared.languageSetting ?? "ja"
    }

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: selectedLanguageCode) }
            .filter {
                if #available(iOS 17.0, *) {
                    return !$0.voiceTraits.contains(.isPersonalVoice)
                }
                return true
            }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    private var hasEnhancedVoice: Bool {
        availableVoices.contains { $0.quality != .default }
    }

    var body: some View {
        Form {
            if !hasEnhancedVoice {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                            Text("高品質音声を使用できます")
                                .font(.headline)
                        }
                        Text("設定 > アクセシビリティ > 読み上げコンテンツ > 声 から高品質音声をダウンロードすると、より自然な読み上げになります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.callout)
                    }
                    .padding(.vertical, 4)
                }
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

            if #available(iOS 17.0, *), selectedLanguageCode.starts(with: "en") {
                PersonalVoiceSection(
                    selectedVoiceIdentifier: store.selectedVoiceIdentifier,
                    speechRate: store.speechRate,
                    speechPitch: store.speechPitch,
                    onSelect: { send(.setVoiceIdentifier($0)) }
                )
            }

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

// MARK: - Personal Voice Section (iOS 17+)

@available(iOS 17.0, *)
private struct PersonalVoiceSection: View {
    let selectedVoiceIdentifier: String?
    let speechRate: Float
    let speechPitch: Float
    let onSelect: (String) -> Void

    @State private var authStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined

    private var personalVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    var body: some View {
        Section(header: Text("パーソナルボイス")) {
            switch authStatus {
            case .notDetermined:
                Button("パーソナルボイスを使用する") {
                    AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                        DispatchQueue.main.async { authStatus = status }
                    }
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
                        Text("パーソナルボイスが作成されていません")
                            .foregroundColor(.secondary)
                            .font(.caption)
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
        let utterance = AVSpeechUtterance(string: "Hello, this is a test.")
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

    @ViewBuilder
    private var qualityBadge: some View {
        switch voice.quality {
        case .enhanced:
            Text("高品質")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(4)
        case .premium:
            Text("プレミアム")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .foregroundColor(.purple)
                .cornerRadius(4)
        default:
            EmptyView()
        }
    }
}
