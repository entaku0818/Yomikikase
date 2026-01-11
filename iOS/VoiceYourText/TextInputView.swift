//
//  TextInputView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
import Dependencies

struct TextInputView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    @State private var text: String = ""
    @State private var isEditMode: Bool = true
    @State private var isSpeaking = false
    @State private var highlightedRange: NSRange? = nil
    @State private var showingSpeedPicker = false
    @State private var isGeneratingAudio = false
    @State private var audioGenerationError: String? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentFileId: UUID?
    @State private var availableVoices: [VoiceConfig] = []
    @State private var selectedVoice: VoiceConfig?
    @State private var showingVoicePicker = false
    @State private var isLoadingVoices = false
    @FocusState private var isTextEditorFocused: Bool
    @Dependency(\.speechSynthesizer) var speechSynthesizer
    @Dependency(\.audioAPI) var audioAPI
    @Dependency(\.audioFileManager) var audioFileManager

    let initialText: String
    let fileId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
                    // 再生中でも止めずにdismiss（ミニプレイヤーで継続）
                    dismiss()
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .padding(.leading, 8)

                Spacer()

                if isEditMode {
                    if isGeneratingAudio {
                        ProgressView()
                            .padding(.trailing, 16)
                    } else {
                        HStack(spacing: 12) {
                            // 音声変更ボタン
                            Button(action: {
                                showingVoicePicker = true
                            }) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            .disabled(isLoadingVoices)

                            // 保存ボタン
                            Button("保存") {
                                saveText()
                            }
                            .disabled(text.isEmpty)
                        }
                        .padding(.trailing, 16)
                    }
                }
            }
            .frame(height: 56)
            .background(Color(UIColor.systemBackground))

            Divider()

            // メインコンテンツ
            if isEditMode {
                // 編集モード
                editModeContent
            } else {
                // プレイヤーモード
                playerModeContent
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            text = initialText
            currentFileId = fileId
            // 既存ファイルを開いた場合はプレイヤーモードで開始
            if fileId != nil && !initialText.isEmpty {
                isEditMode = false
            } else if initialText.isEmpty {
                // 新規作成時はキーボードを自動表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextEditorFocused = true
                }
            }

            // nowPlayingと同期（ミニプレイヤーから戻ってきた場合）
            let nowPlaying = store.withState { $0.nowPlaying }
            if nowPlaying.isPlaying {
                if case .textInput(let sourceFileId, _) = nowPlaying.source {
                    if sourceFileId == fileId {
                        isSpeaking = true
                        isEditMode = false
                    }
                }
            }

            // 利用可能な音声を読み込む
            loadAvailableVoices()
        }
        .sheet(isPresented: $showingVoicePicker) {
            VoicePickerSheet(
                voices: availableVoices,
                selectedVoice: $selectedVoice,
                isLoading: isLoadingVoices,
                onSelect: {
                    showingVoicePicker = false
                }
            )
        }
        .confirmationDialog("再生速度", isPresented: $showingSpeedPicker, titleVisibility: .visible) {
            ForEach(SpeechSettings.speedOptions, id: \.self) { speed in
                Button(SpeechSettings.formatSpeedOption(speed)) {
                    UserDefaultsManager.shared.speechRate = speed
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - 編集モード
    private var editModeContent: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 20))
                .padding(.horizontal)
                .padding(.top, 8)
                .focused($isTextEditorFocused)

            // プレースホルダー
            if text.isEmpty {
                Text("読み上げたいテキストを入力してください...")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - プレイヤーモード
    private var playerModeContent: some View {
        VStack(spacing: 0) {
            // テキスト表示（読み取り専用）
            // UITextViewは自身でスクロールするため、外側のScrollViewは不要
            HighlightableTextView(
                text: .constant(text),
                highlightedRange: $highlightedRange,
                isEditable: false,
                fontSize: 20
            )
            .padding(.horizontal)
            .padding(.top, 16)

            // 広告バナー
            if !UserDefaultsManager.shared.isPremiumUser {
                AdmobBannerView()
                    .frame(height: 50)
            }

            // プレイヤーコントロール
            PlayerControlView(
                isSpeaking: isSpeaking,
                isTextEmpty: text.isEmpty,
                speechRate: UserDefaultsManager.shared.speechRate,
                onPlay: {
                    speakWithHighlight()
                },
                onStop: {
                    stopSpeaking()
                },
                onSpeedTap: {
                    showingSpeedPicker = true
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func speakWithHighlight() {
        guard !text.isEmpty else {
            warningLog("TextInputView: Cannot speak - text is empty")
            return
        }

        isSpeaking = true

        // nowPlayingを更新（ミニプレイヤー用）
        let title = String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        store.send(.nowPlaying(.startPlaying(title: title, text: text, source: .textInput(fileId: fileId, text: text))))

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            errorLog("Failed to set audio session category: \(error)")
            return
        }

        // Check if downloaded Cloud TTS audio exists
        if let currentFileId = currentFileId {
            // Direct file system check for audio file
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDirectory = documentsURL.appendingPathComponent("audio", isDirectory: true)
            let audioPath = audioDirectory.appendingPathComponent("\(currentFileId.uuidString).wav")

            if fileManager.fileExists(atPath: audioPath.path) {
                infoLog("Playing Cloud TTS audio: \(audioPath.path)")
                playDownloadedAudio(url: audioPath)
                return
            } else {
                infoLog("Audio file not found for fileId: \(currentFileId.uuidString)")
            }
        }

        // Fallback to device TTS
        infoLog("Using device TTS (no Cloud TTS audio available)")
        playWithDeviceTTS()
    }

    private func playDownloadedAudio(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            // Set up completion handler using NotificationCenter
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AudioPlayerFinished"),
                object: nil,
                queue: .main
            ) { [weak audioPlayer] _ in
                guard audioPlayer != nil else { return }
                self.isSpeaking = false
                self.highlightedRange = nil
                self.store.send(.nowPlaying(.stopPlaying))
            }
            audioPlayer?.delegate = CloudTTSAudioDelegate.shared
            audioPlayer?.play()
        } catch {
            errorLog("Failed to play downloaded audio: \(error)")
            // Fallback to device TTS
            playWithDeviceTTS()
        }
    }

    private func playWithDeviceTTS() {
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75

        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume

        Task {
            do {
                try await speechSynthesizer.speakWithHighlight(
                    speechUtterance,
                    { range, _ in
                        DispatchQueue.main.async {
                            highlightedRange = range
                        }
                    },
                    {
                        DispatchQueue.main.async {
                            isSpeaking = false
                            highlightedRange = nil
                            // 読み上げ完了時はnowPlayingを停止（コンテンツは保持）
                            store.send(.nowPlaying(.stopPlaying))
                        }
                    }
                )
            } catch {
                errorLog("Speech synthesis failed: \(error)")
                DispatchQueue.main.async {
                    isSpeaking = false
                    highlightedRange = nil
                    store.send(.nowPlaying(.stopPlaying))
                }
            }
        }
    }

    private func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        highlightedRange = nil
        store.send(.nowPlaying(.stopPlaying))
    }

    private func saveText() {
        let finalTitle = String(text.prefix(20))
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english

        var savedFileId: UUID
        if let fileId = fileId {
            infoLog("[TTS] Updating existing text with fileId: \(fileId)")
            SpeechTextRepository.shared.updateSpeechText(
                id: fileId,
                title: finalTitle,
                text: text
            )
            savedFileId = fileId
        } else {
            savedFileId = SpeechTextRepository.shared.insert(
                title: finalTitle,
                text: text,
                languageSetting: languageSetting
            )
            infoLog("[TTS] Created new text with savedFileId: \(savedFileId)")
            // Update currentFileId for new texts
            currentFileId = savedFileId
            infoLog("[TTS] Set currentFileId to: \(savedFileId)")
        }

        // Generate TTS audio in background
        infoLog("[TTS] Starting TTS generation for fileId: \(savedFileId)")
        generateTTSAudio(for: savedFileId, text: text, languageCode: languageCode)
    }

    private func generateTTSAudio(for fileId: UUID, text: String, languageCode: String) {
        isGeneratingAudio = true
        audioGenerationError = nil

        // Use selected voice or fallback to language mapping
        let voiceId = selectedVoice?.id ?? mapLanguageToVoiceId(languageCode)
        infoLog("[TTS] Generating audio with voiceId: \(voiceId), fileId: \(fileId)")

        Task {
            do {
                // Generate audio via Cloud Run TTS
                infoLog("[TTS] Calling Cloud Run API...")
                let response = try await audioAPI.generateAudio(text, voiceId)
                infoLog("[TTS] API response received, audioUrl: \(response.audioUrl)")

                guard let audioURL = URL(string: response.audioUrl) else {
                    infoLog("[TTS] ERROR: Invalid audio URL")
                    throw AudioAPIError.invalidURL
                }

                // Download audio to local storage
                infoLog("[TTS] Downloading audio from: \(audioURL)")
                let localURL = try await audioFileManager.downloadAudio(audioURL, fileId.uuidString)
                infoLog("[TTS] Audio downloaded and saved to: \(localURL.path)")
                infoLog("Audio saved to: \(localURL.path)")

                await MainActor.run {
                    isGeneratingAudio = false
                    isEditMode = false
                    infoLog("[TTS] Switched to player mode")
                }
            } catch {
                infoLog("[TTS] ERROR: TTS generation failed: \(error)")
                errorLog("TTS generation failed: \(error)")
                await MainActor.run {
                    isGeneratingAudio = false
                    audioGenerationError = error.localizedDescription
                    // Still switch to player mode even if TTS fails
                    isEditMode = false
                }
            }
        }
    }

    private func mapLanguageToVoiceId(_ languageCode: String) -> String {
        // Map language code to Cloud Run TTS voice ID
        switch languageCode.lowercased() {
        case "ja", "ja-jp":
            return "ja-jp-female-a"
        case "en", "en-us":
            return "en-us-female-a"
        case "en-gb":
            return "en-us-female-a" // Fallback to US voice
        default:
            // Default to Japanese if unknown
            return "ja-jp-female-a"
        }
    }

    private func loadAvailableVoices() {
        isLoadingVoices = true
        Task {
            do {
                let response = try await audioAPI.getVoices(nil)
                await MainActor.run {
                    availableVoices = response.voices
                    // Set default selection based on language setting
                    let languageCode = UserDefaultsManager.shared.languageSetting ?? "ja"
                    if let savedVoiceId = UserDefaultsManager.shared.cloudTTSVoiceId,
                       let savedVoice = response.voices.first(where: { $0.id == savedVoiceId }) {
                        selectedVoice = savedVoice
                    } else if let defaultVoice = response.voices.first(where: { $0.language.lowercased().hasPrefix(languageCode.lowercased()) }) {
                        selectedVoice = defaultVoice
                    } else {
                        selectedVoice = response.voices.first
                    }
                    isLoadingVoices = false
                }
            } catch {
                errorLog("Failed to load voices: \(error)")
                await MainActor.run {
                    isLoadingVoices = false
                }
            }
        }
    }
}

// MARK: - Voice Picker Sheet
struct VoicePickerSheet: View {
    let voices: [VoiceConfig]
    @Binding var selectedVoice: VoiceConfig?
    let isLoading: Bool
    let onSelect: () -> Void

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("音声を読み込み中...")
                } else if voices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("音声が見つかりません")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(groupedVoices.keys.sorted(), id: \.self) { language in
                            Section(header: Text(languageDisplayName(language))) {
                                ForEach(groupedVoices[language] ?? [], id: \.id) { voice in
                                    VoiceRow(
                                        voice: voice,
                                        isSelected: selectedVoice?.id == voice.id,
                                        onSelect: {
                                            selectedVoice = voice
                                            UserDefaultsManager.shared.cloudTTSVoiceId = voice.id
                                            onSelect()
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("音声を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        onSelect()
                    }
                }
            }
        }
    }

    private var groupedVoices: [String: [VoiceConfig]] {
        Dictionary(grouping: voices, by: { $0.language })
    }

    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "ja-JP":
            return "日本語"
        case "en-US":
            return "英語 (US)"
        case "en-GB":
            return "英語 (UK)"
        default:
            return code
        }
    }
}

struct VoiceRow: View {
    let voice: VoiceConfig
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(voice.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Label(voice.gender == "female" ? "女性" : "男性", systemImage: voice.gender == "female" ? "person.fill" : "person")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Cloud TTS Audio Delegate
class CloudTTSAudioDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = CloudTTSAudioDelegate()

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NotificationCenter.default.post(name: NSNotification.Name("AudioPlayerFinished"), object: nil)
    }
}

#Preview("Edit Mode") {
    TextInputView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        initialText: "",
        fileId: nil
    )
}

#Preview("Player Mode") {
    TextInputView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        initialText: "これはサンプルテキストです。読み上げのテストを行います。",
        fileId: UUID()
    )
}
