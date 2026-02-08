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
    @State private var currentTimepoints: [TTSTimepoint] = []
    @State private var highlightTimer: Timer?
    @State private var playbackStartTime: Date?
    @State private var useCloudTTS: Bool = true // デフォルトはクラウドTTS
    @State private var cloudTTSAvailable: Bool = false // クラウドTTS音声が利用可能か
    @FocusState private var isTextEditorFocused: Bool
    @Dependency(\.speechSynthesizer) var speechSynthesizer
    @Dependency(\.audioAPI) var audioAPI
    @Dependency(\.audioFileManager) var audioFileManager

    let initialText: String
    let fileId: UUID?
    let fileType: String?
    let imagePaths: [String]?

    init(store: Store<Speeches.State, Speeches.Action>, initialText: String, fileId: UUID?, fileType: String? = nil, imagePaths: [String]? = nil) {
        self.store = store
        self.initialText = initialText
        self.fileId = fileId
        self.fileType = fileType
        self.imagePaths = imagePaths
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
                    // 閉じる時は必ず再生を停止
                    stopSpeaking()
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
                } else {
                    // プレイヤーモードでは編集ボタンを表示
                    Button(action: {
                        stopSpeaking()
                        isEditMode = true
                        // キーボードを表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextEditorFocused = true
                        }
                    }) {
                        Text("編集")
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 16)
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

            // 既存ファイルの場合、保存されたTTSモードを読み込む
            if let fileId = fileId {
                let savedTTSMode = SpeechTextRepository.shared.fetchTTSMode(id: fileId)
                useCloudTTS = savedTTSMode == "cloud"
                infoLog("[TTS] Loaded TTS mode for fileId \(fileId): \(savedTTSMode ?? "nil"), useCloudTTS: \(useCloudTTS)")
            }

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

            // クラウドTTS音声の利用可否をチェック
            checkCloudTTSAvailability()
        }
        .onDisappear {
            // Viewが閉じられる時も念のため停止
            stopSpeaking()
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
        VStack(spacing: 0) {
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

            Spacer()

            // TTS方式選択
            VStack(spacing: 12) {
                HStack {
                    Text("音声エンジン:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("", selection: $useCloudTTS) {
                        Text("クラウドTTS").tag(true)
                        Text("基本TTS").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 250)
                }

                if useCloudTTS {
                    Text("高品質な音声で保存します（処理に時間がかかります）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("デバイスの基本音声で再生します（保存は不要です）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
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

            // 使用中のTTSモード表示
            if cloudTTSAvailable && useCloudTTS {
                HStack {
                    Image(systemName: "cloud.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("クラウドTTSで再生")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if !useCloudTTS {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("基本TTSで再生")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

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

    private func checkCloudTTSAvailability() {
        guard let currentFileId = currentFileId else {
            cloudTTSAvailable = false
            return
        }

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsURL.appendingPathComponent("audio", isDirectory: true)
        let audioPath = audioDirectory.appendingPathComponent("\(currentFileId.uuidString).wav")

        cloudTTSAvailable = fileManager.fileExists(atPath: audioPath.path)
        infoLog("[TTS Mode] Cloud TTS available: \(cloudTTSAvailable)")
    }

    private func speakWithHighlight() {
        guard !text.isEmpty else {
            warningLog("TextInputView: Cannot speak - text is empty")
            return
        }

        // 既存の再生を完全に停止
        stopSpeaking()

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

        // Check user preference and Cloud TTS availability
        infoLog("[Highlight] useCloudTTS: \(useCloudTTS), cloudTTSAvailable: \(cloudTTSAvailable)")
        if useCloudTTS && cloudTTSAvailable, let currentFileId = currentFileId {
            // User prefers Cloud TTS and it's available
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDirectory = documentsURL.appendingPathComponent("audio", isDirectory: true)
            let audioPath = audioDirectory.appendingPathComponent("\(currentFileId.uuidString).wav")

            if fileManager.fileExists(atPath: audioPath.path) {
                infoLog("[Highlight] Playing Cloud TTS audio: \(audioPath.path)")
                playDownloadedAudio(url: audioPath)
                return
            }
        }

        // Use device TTS (with highlight support)
        infoLog("[Highlight] Using device TTS (WITH highlight support)")
        playWithDeviceTTS()
    }

    private func playDownloadedAudio(url: URL) {
        // 既存のaudioPlayerを停止
        audioPlayer?.stop()
        audioPlayer = nil

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)

            // 速度設定を適用
            audioPlayer?.enableRate = true
            // AVAudioPlayerのrateは0.5〜2.0（AVSpeechUtteranceは0.0〜1.0でデフォルト0.5）
            // speechRate 0.5 = 通常速度なので、AVAudioPlayer rate 1.0に対応
            // speechRate 1.0 = 2倍速なので、AVAudioPlayer rate 2.0に対応
            let speechRate = UserDefaultsManager.shared.speechRate
            let playbackRate = max(0.5, min(2.0, speechRate * 2.0))
            audioPlayer?.rate = playbackRate

            // Load timepoints from JSON file if available
            let timepointsURL = url.deletingPathExtension().appendingPathExtension("json")
            if FileManager.default.fileExists(atPath: timepointsURL.path) {
                do {
                    let timepointsData = try Data(contentsOf: timepointsURL)
                    currentTimepoints = try JSONDecoder().decode([TTSTimepoint].self, from: timepointsData)
                    infoLog("[Highlight] Loaded \(currentTimepoints.count) timepoints from file")
                } catch {
                    errorLog("[Highlight] Failed to load timepoints: \(error)")
                    currentTimepoints = []
                }
            }

            // Set up completion handler using NotificationCenter
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AudioPlayerFinished"),
                object: nil,
                queue: .main
            ) { [weak audioPlayer] _ in
                guard audioPlayer != nil else { return }
                self.stopHighlightTimer()
                self.isSpeaking = false
                self.highlightedRange = nil
                self.store.send(.nowPlaying(.stopPlaying))
            }
            audioPlayer?.delegate = CloudTTSAudioDelegate.shared

            // Start highlight timer if we have timepoints
            if !currentTimepoints.isEmpty {
                startHighlightTimer(playbackRate: playbackRate)
            }

            audioPlayer?.play()
        } catch {
            errorLog("Failed to play downloaded audio: \(error)")
            // Fallback to device TTS
            playWithDeviceTTS()
        }
    }

    private func startHighlightTimer(playbackRate: Float) {
        playbackStartTime = Date()
        highlightTimer?.invalidate()

        // Update highlights at 60fps for smooth animation
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [self] _ in
            guard let startTime = playbackStartTime else { return }

            // Calculate current playback time (adjusted for rate)
            let elapsedTime = Date().timeIntervalSince(startTime) * Double(playbackRate)

            // Find the current timepoint
            var currentRange: NSRange? = nil
            for (index, timepoint) in currentTimepoints.enumerated() {
                if timepoint.timeSeconds <= elapsedTime {
                    // Check if next timepoint hasn't started yet
                    let nextIndex = index + 1
                    if nextIndex < currentTimepoints.count {
                        if currentTimepoints[nextIndex].timeSeconds > elapsedTime {
                            currentRange = timepoint.textRange
                            break
                        }
                    } else {
                        // Last timepoint
                        currentRange = timepoint.textRange
                    }
                }
            }

            DispatchQueue.main.async {
                if self.highlightedRange != currentRange {
                    self.highlightedRange = currentRange
                }
            }
        }
    }

    private func stopHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = nil
        playbackStartTime = nil
    }

    private func playWithDeviceTTS() {
        infoLog("[Highlight] playWithDeviceTTS called")
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        let volume: Float = 0.75
        infoLog("[Highlight] language: \(language), rate: \(rate), pitch: \(pitch)")

        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: language)
        speechUtterance.rate = rate
        speechUtterance.pitchMultiplier = pitch
        speechUtterance.volume = volume

        Task {
            do {
                infoLog("[Highlight] Starting speakWithHighlight")
                try await speechSynthesizer.speakWithHighlight(
                    speechUtterance,
                    { range, _ in
                        infoLog("[Highlight] Highlight callback: location=\(range.location), length=\(range.length)")
                        DispatchQueue.main.async {
                            self.highlightedRange = range
                            infoLog("[Highlight] highlightedRange set to: \(range)")
                        }
                    },
                    {
                        infoLog("[Highlight] Speech finished callback")
                        DispatchQueue.main.async {
                            self.isSpeaking = false
                            self.highlightedRange = nil
                            // 読み上げ完了時はnowPlayingを停止（コンテンツは保持）
                            self.store.send(.nowPlaying(.stopPlaying))
                        }
                    }
                )
                infoLog("[Highlight] speakWithHighlight completed")
            } catch {
                errorLog("[Highlight] Speech synthesis failed: \(error)")
                DispatchQueue.main.async {
                    self.isSpeaking = false
                    self.highlightedRange = nil
                    self.store.send(.nowPlaying(.stopPlaying))
                }
            }
        }
    }

    private func stopSpeaking() {
        stopHighlightTimer()
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
        let ttsMode = useCloudTTS ? "cloud" : "basic"

        // imagePathsをJSON文字列に変換
        var imagePathString: String? = nil
        if let imagePaths = imagePaths, !imagePaths.isEmpty {
            if let jsonData = try? JSONEncoder().encode(imagePaths),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                imagePathString = jsonString
            }
        }

        var savedFileId: UUID
        if let fileId = fileId {
            infoLog("[TTS] Updating existing text with fileId: \(fileId), ttsMode: \(ttsMode)")
            SpeechTextRepository.shared.updateSpeechText(
                id: fileId,
                title: finalTitle,
                text: text,
                ttsMode: ttsMode
            )
            savedFileId = fileId
        } else {
            savedFileId = SpeechTextRepository.shared.insert(
                title: finalTitle,
                text: text,
                languageSetting: languageSetting,
                fileType: fileType ?? "text",
                imagePath: imagePathString,
                ttsMode: ttsMode
            )
            infoLog("[TTS] Created new text with savedFileId: \(savedFileId), ttsMode: \(ttsMode)")
            // Update currentFileId for new texts
            currentFileId = savedFileId
            infoLog("[TTS] Set currentFileId to: \(savedFileId)")
        }

        // Generate TTS audio only if Cloud TTS is selected
        if useCloudTTS {
            infoLog("[TTS] Starting Cloud TTS generation for fileId: \(savedFileId)")
            generateTTSAudio(for: savedFileId, text: text, languageCode: languageCode)
        } else {
            infoLog("[TTS] Using Basic TTS, skipping audio generation")
            // Switch to player mode immediately for Basic TTS
            cloudTTSAvailable = false
            isEditMode = false
        }
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
                infoLog("[TTS] Received \(response.timepoints?.count ?? 0) timepoints")

                guard let audioURL = URL(string: response.audioUrl) else {
                    infoLog("[TTS] ERROR: Invalid audio URL")
                    throw AudioAPIError.invalidURL
                }

                // Download audio to local storage
                infoLog("[TTS] Downloading audio from: \(audioURL)")
                let localURL = try await audioFileManager.downloadAudio(audioURL, fileId.uuidString)
                infoLog("[TTS] Audio downloaded and saved to: \(localURL.path)")

                // Save timepoints to JSON file
                if let timepoints = response.timepoints, !timepoints.isEmpty {
                    let timepointsURL = localURL.deletingPathExtension().appendingPathExtension("json")
                    let timepointsData = try JSONEncoder().encode(timepoints)
                    try timepointsData.write(to: timepointsURL)
                    infoLog("[TTS] Timepoints saved to: \(timepointsURL.path)")
                }

                await MainActor.run {
                    currentTimepoints = response.timepoints ?? []
                    isGeneratingAudio = false
                    isEditMode = false
                    cloudTTSAvailable = true // クラウドTTS音声が生成された
                    infoLog("[TTS] Switched to player mode with Cloud TTS available")
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
        case "en", "en-us", "en-gb":
            return "en-us-female-a"
        case "de", "de-de":
            return "de-de-female-a"
        case "es", "es-es":
            return "es-es-female-a"
        case "fr", "fr-fr":
            return "fr-fr-female-a"
        case "it", "it-it":
            return "it-it-female-a"
        case "ko", "ko-kr":
            return "ko-kr-female-a"
        case "tr", "tr-tr":
            return "tr-tr-female-a"
        case "vi", "vi-vn":
            return "vi-vn-female-a"
        case "th", "th-th":
            return "th-th-female-a"
        default:
            return "ja-jp-female-a"
        }
    }

    private func mapLanguageToLocale(_ languageCode: String) -> String {
        // Map short language code to full locale for Cloud TTS API
        switch languageCode.lowercased() {
        case "ja", "ja-jp":
            return "ja-JP"
        case "en", "en-us":
            return "en-US"
        case "de", "de-de":
            return "de-DE"
        case "es", "es-es":
            return "es-ES"
        case "fr", "fr-fr":
            return "fr-FR"
        case "it", "it-it":
            return "it-IT"
        case "ko", "ko-kr":
            return "ko-KR"
        case "tr", "tr-tr":
            return "tr-TR"
        case "vi", "vi-vn":
            return "vi-VN"
        case "th", "th-th":
            return "th-TH"
        default:
            return "ja-JP"
        }
    }

    private func loadAvailableVoices() {
        isLoadingVoices = true
        Task {
            do {
                // Filter voices by current language setting
                let languageCode = UserDefaultsManager.shared.languageSetting ?? "ja"
                let locale = mapLanguageToLocale(languageCode)
                let response = try await audioAPI.getVoices(locale)
                await MainActor.run {
                    availableVoices = response.voices
                    // Set default selection based on saved voice or language
                    if let savedVoiceId = UserDefaultsManager.shared.cloudTTSVoiceId,
                       let savedVoice = response.voices.first(where: { $0.id == savedVoiceId }) {
                        selectedVoice = savedVoice
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
        case "de-DE":
            return "ドイツ語"
        case "es-ES":
            return "スペイン語"
        case "fr-FR":
            return "フランス語"
        case "it-IT":
            return "イタリア語"
        case "ko-KR":
            return "韓国語"
        case "tr-TR":
            return "トルコ語"
        case "vi-VN":
            return "ベトナム語"
        case "th-TH":
            return "タイ語"
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
