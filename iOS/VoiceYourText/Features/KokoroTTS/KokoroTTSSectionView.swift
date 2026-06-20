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
                    .foregroundStyle(.indigo)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Kokoro AI音声")
                            .font(.headline)
                        Text("Beta")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.15))
                            .foregroundStyle(.indigo)
                            .clipShape(Capsule())
                    }
                    Text("MLX・完全オンデバイス生成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

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
            Text(isJapanese ? "Kokoro AI音声（日本語）" : "Kokoro AI音声（英語）")
        }
        .task {
            for await status in await KokoroModelManager.shared.statusStream() {
                downloadStatus = status
            }
        }
    }

    // MARK: - Sub-rows

    private var downloadPromptRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("モデルをダウンロードするとオンデバイスで高品質な音声が使えます（約600MB）")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                startDownload()
            } label: {
                Label("ダウンロード", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
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
                .tint(.indigo)
            Button("キャンセル", role: .destructive) {
                cancelDownload()
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var enabledRow: some View {
        VStack(spacing: 14) {
            Toggle(isOn: Binding(get: { kokoroEnabled }, set: { onToggle($0) })) {
                Text("Kokoro AI音声を使用")
            }
            .tint(.indigo)

            if kokoroEnabled {
                voiceCardList
            }

            Button(role: .destructive) {
                Task { try? await KokoroModelManager.shared.deleteModel() }
            } label: {
                Label("モデルを削除（約600MB）", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Voice card list

    private var availableVoices: [KokoroVoice] {
        KokoroVoice.allCases.filter { $0.isJapanese == isJapanese }
    }

    private var voiceCardList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("声のキャラクター")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(availableVoices) { voice in
                VoiceCharacterCard(
                    voice: voice,
                    isSelected: kokoroVoice == voice.rawValue,
                    onSelect: { onSelectVoice(voice.rawValue) }
                )
            }
        }
    }

    // MARK: - Error row

    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
            Button { startDownload() } label: { Text("再試行") }
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

// MARK: - Voice Character Card

private struct VoiceCharacterCard: View {
    let voice: KokoroVoice
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Gender icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.indigo : Color.indigo.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: voice.gender.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .white : .indigo)
                }

                // Name + persona + accent
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(voice.characterName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(voice.accent.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                    Text(voice.persona)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Trial play button
                Button {
                    playPreview()
                } label: {
                    Image(systemName: isPlaying ? "waveform" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(isPlaying ? Color.indigo : Color.secondary)
                        .symbolEffect(.variableColor, isActive: isPlaying)
                }
                .buttonStyle(.plain)
                .disabled(isPlaying)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.indigo.opacity(0.07) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.indigo : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func playPreview() {
        guard !isPlaying else { return }
        isPlaying = true
        Task {
            defer { isPlaying = false }
            do {
                let data = try await KokoroTTSClient.liveValue.synthesize(
                    voice.sampleText,
                    voice,
                    1.0
                )
                await MainActor.run {
                    audioPlayer = try? AVAudioPlayer(data: data)
                    audioPlayer?.play()
                }
            } catch {
                print("[KokoroVoiceCard] preview error: \(error)")
            }
        }
    }
}
