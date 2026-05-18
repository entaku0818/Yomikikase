import SwiftUI
import AVFoundation

struct KokoroTTSSection: View {
    let kokoroEnabled: Bool
    let kokoroVoice: String
    let isJapanese: Bool
    let onToggle: (Bool) -> Void
    let onSelectVoice: (String) -> Void

    @State private var downloadStatus: KokoroDownloadStatus = .notDownloaded
    @State private var downloadTask: Task<Void, Never>?

    var body: some View {
        Section {
            // ヘッダー行
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.mic")
                    .foregroundStyle(.purple)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Kokoro AI音声")
                            .font(.headline)
                        Text("Beta")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                    Text("ニューラルTTS・完全オンデバイス")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            // ダウンロード状態に応じたUI
            switch downloadStatus {
            case .notDownloaded:
                downloadPromptRow
            case .downloading(let progress):
                downloadProgressRow(progress: progress)
            case .downloaded:
                enabledRow
            case .failed(let message):
                errorRow(message: message)
            }
        } header: {
            Text(isJapanese ? "Kokoro AI音声（日本語）" : "Kokoro AI音声（英語専用）")
        }
        .task {
            for await status in await KokoroModelManager.shared.statusStream() {
                downloadStatus = status
            }
        }
    }

    // MARK: - Sub-rows

    private var downloadPromptRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("モデルをダウンロードすると高品質な英語音声が使えます（約600MB）")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                startDownload()
            } label: {
                Label("ダウンロード", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(.vertical, 4)
    }

    private func downloadProgressRow(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ダウンロード中…")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(.purple)
            Button("キャンセル", role: .destructive) {
                cancelDownload()
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var enabledRow: some View {
        VStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { kokoroEnabled },
                set: { onToggle($0) }
            )) {
                Text("Kokoro TTS を使用")
            }
            .tint(.purple)

            if kokoroEnabled {
                voicePickerRow
                testPlayButton
            }

            Button(role: .destructive) {
                Task {
                    try? await KokoroModelManager.shared.deleteModel()
                }
            } label: {
                Label("モデルを削除（600MB）", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @State private var isTestPlaying = false
    @State private var audioPlayer: AVAudioPlayer?

    private var testPlayButton: some View {
        Button {
            guard !isTestPlaying else { return }
            isTestPlaying = true
            Task {
                defer { isTestPlaying = false }
                do {
                    let defaultVoice: KokoroVoice = isJapanese ? .defaultJapanese : .default
                    let voice = KokoroVoice(rawValue: kokoroVoice) ?? defaultVoice
                    let testText = isJapanese
                        ? "こんにちは！これはKokoro TTSのテストです。"
                        : "Hello! This is Kokoro TTS running on your device."
                    let data = try await KokoroTTSClient.liveValue.synthesize(testText, voice, 1.0)
                    await MainActor.run {
                        audioPlayer = try? AVAudioPlayer(data: data)
                        audioPlayer?.play()
                    }
                } catch {
                    print("Kokoro test error: \(error)")
                }
            }
        } label: {
            Label(
                isTestPlaying ? "生成中…" : "テスト再生",
                systemImage: isTestPlaying ? "waveform" : "play.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.purple)
        .disabled(isTestPlaying)
    }

    private var voicePickerRow: some View {
        let availableVoices = KokoroVoice.allCases.filter { $0.isJapanese == isJapanese }
        return VStack(alignment: .leading, spacing: 6) {
            Text("音声スタイル")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableVoices) { voice in
                        Button {
                            onSelectVoice(voice.rawValue)
                        } label: {
                            Text(voice.displayName)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    kokoroVoice == voice.rawValue
                                        ? Color.purple
                                        : Color.purple.opacity(0.1)
                                )
                                .foregroundStyle(
                                    kokoroVoice == voice.rawValue
                                        ? Color.white
                                        : Color.purple
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
            Button {
                startDownload()
            } label: {
                Text("再試行")
            }
        }
    }

    // MARK: - Actions

    private func startDownload() {
        downloadTask = Task {
            do {
                try await KokoroModelManager.shared.download()
            } catch {
                await MainActor.run {
                    downloadStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        Task { await MainActor.run { downloadStatus = .notDownloaded } }
    }
}
