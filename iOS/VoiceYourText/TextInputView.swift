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
    @State private var showingTTSInfo = false
    @State private var audioPlayer: AVAudioPlayer?
    // AudioPlayerFinished observer のトークン。再生の度に addObserver が積み重ならないよう保持し、
    // 再登録前・再生停止時に removeObserver する。
    @State private var audioFinishObserver: NSObjectProtocol?
    @State private var currentFileId: UUID?
    /// 旧クラウドTTSで生成済みの音声ファイルを持つ既存ファイルかどうか。
    /// クラウドTTS撤去後も、すでにユーザーの端末にある音声資産はそのまま再生できるようにする。
    /// 新規生成の導線は無いため、true になるのは撤去前に生成された既存レコードだけ。
    @State private var hasGeneratedAudio: Bool = false
    @State private var showingTextLimitAlert = false
    @State private var showingSubscription = false
    @FocusState private var isTextEditorFocused: Bool
    @Dependency(\.speechSynthesizer) var speechSynthesizer
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
                    // 保存ボタン（文字数が多い場合は保存せず再生）
                    Button(text.count > 4_000 ? "再生" : "保存") {
                        handleSaveButtonTap()
                    }
                    .disabled(text.isEmpty)
                    .padding(.trailing, 16)
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

            // 既存ファイルに旧クラウドTTSの音声ファイルが残っていれば、それを再生に使う
            checkGeneratedAudio()

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

        }
        .onDisappear {
            // Viewが閉じられる時も念のため停止
            stopSpeaking()
        }
        .confirmationDialog("再生速度", isPresented: $showingSpeedPicker, titleVisibility: .visible) {
            ForEach(SpeechSettings.speedOptions, id: \.self) { speed in
                Button(SpeechSettings.formatSpeedOption(speed)) {
                    UserDefaultsManager.shared.speechRate = speed
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showingTTSInfo) {
            TTSInfoSheet(
                hasGeneratedAudio: hasGeneratedAudio,
                speechRate: UserDefaultsManager.shared.speechRate,
                speechPitch: UserDefaultsManager.shared.speechPitch
            )
            .presentationDetents([.medium, .large])
        }
        .alert("文字数制限", isPresented: $showingTextLimitAlert) {
            Button("プレミアムプランを確認") {
                showingSubscription = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("4,000文字を超えるテキストはプレミアムプランでのみご利用いただけます。")
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView(source: "text_char_limit")
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

            // 再生方式の説明
            VStack(spacing: 12) {
                if text.count > 4_000 {
                    Text("文字数が多いため、端末TTSで直接再生します（保存されません）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("オンデバイス音声で再生します（インターネット不要）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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
                },
                onTTSInfoTap: {
                    showingTTSInfo = true
                }
            )
        }
    }

    // MARK: - Helper Functions

    /// 撤去前のクラウドTTSで生成された音声ファイルが端末に残っているかを調べる。
    /// `ttsMode == "cloud"` のレコードに限定することで、テキストを編集して保存し直した
    /// ファイル（= ttsMode が "basic" に上書きされる）で古い音声を再生してしまうのを防ぐ。
    private func checkGeneratedAudio() {
        guard let currentFileId = currentFileId else {
            hasGeneratedAudio = false
            return
        }
        hasGeneratedAudio = SpeechTextRepository.shared.fetchTTSMode(id: currentFileId) == "cloud"
            && audioFileManager.audioExists(currentFileId.uuidString)
        infoLog("[TTS] Generated audio available: \(hasGeneratedAudio)")
    }

    private func speakWithHighlight() {
        guard !text.isEmpty else {
            warningLog("TextInputView: Cannot speak - text is empty")
            return
        }
        // re-entry防止: isSpeaking=true を先に立てて二重起動をブロック
        // stopSpeaking() を呼ぶと isSpeaking=false になるので、inline で stop 処理を行う
        guard !isSpeaking else { return }
        isSpeaking = true

        // 既存の再生を停止（isSpeaking は変えない）
        removeAudioFinishObserver()
        audioPlayer?.stop()
        audioPlayer = nil
        highlightedRange = nil
        store.send(.nowPlaying(.stopPlaying))
        Task { await speechSynthesizer.stopSpeaking() }

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

        // 撤去前に生成済みの音声ファイルがあれば、それをそのまま再生する（新規生成はしない）
        if hasGeneratedAudio, let currentFileId = currentFileId,
           let audioPath = audioFileManager.getLocalAudioPath(currentFileId.uuidString) {
            infoLog("[Highlight] Playing previously generated audio: \(audioPath.path)")
            playGeneratedAudio(url: audioPath)
            return
        }

        // Kokoro AI (local MLX) → fallback to device TTS
        let kokoroAvailable = KokoroTTSClient.liveValue.isAvailable()
        let kokoroEnabled = UserDefaultsManager.shared.kokoroEnabled
        print("🔊 [TTS] kokoroAvailable=\(kokoroAvailable) kokoroEnabled=\(kokoroEnabled) textLen=\(text.count)")
        if KokoroPlaybackParams.shouldUseKokoro(available: kokoroAvailable, enabled: kokoroEnabled) {
            print("🤖 [TTS] → Kokoro AI (local MLX)")
            playWithKokoroTTS()
        } else {
            print("📢 [TTS] → Device TTS (AVSpeechSynthesizer) — model not downloaded or disabled")
            playWithDeviceTTS()
        }
    }

    /// 撤去前のクラウドTTSで生成され、端末に保存済みの音声ファイルを再生する。
    /// ワード単位のタイムポイントはサーバー由来だったため撤去済みで、この経路にハイライトは無い。
    private func playGeneratedAudio(url: URL) {
        // 既存のaudioPlayerを停止
        audioPlayer?.stop()
        audioPlayer = nil

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayer = player

            setupAndPlayAudioPlayer(player) {
                self.isSpeaking = false
                self.highlightedRange = nil
                self.store.send(.nowPlaying(.stopPlaying))
            }
        } catch {
            errorLog("Failed to play saved audio: \(error)")
            // Fallback to device TTS
            playWithDeviceTTS()
        }
    }

    /// AVAudioPlayer の共通セットアップと再生を行う。
    /// enableRate/rate（再生速度）設定、AudioPlayerFinished observer の再登録（多重登録防止のため
    /// 既存トークンを解放してから登録）、delegate 設定、play() を一元化する。
    /// 保存済み音声（playGeneratedAudio）と Kokoro（playWithKokoroTTS）で重複していた処理の共通化。
    private func setupAndPlayAudioPlayer(_ player: AVAudioPlayer, onFinish: @escaping () -> Void) {
        // 速度設定を適用
        // AVAudioPlayerのrateは0.5〜2.0（AVSpeechUtteranceは0.0〜1.0でデフォルト0.5）
        // speechRate 0.5 = 通常速度なので、AVAudioPlayer rate 1.0に対応
        // speechRate 1.0 = 2倍速なので、AVAudioPlayer rate 2.0に対応
        player.enableRate = true
        player.rate = KokoroPlaybackParams.avPlaybackRate(fromSpeechRate: UserDefaultsManager.shared.speechRate)

        // 既存の observer を解放してから再登録する（再生の度に積み重なるのを防ぐ）
        removeAudioFinishObserver()
        audioFinishObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AudioPlayerFinished"),
            object: nil,
            queue: .main
        ) { [weak player] _ in
            guard player != nil else { return }
            self.removeAudioFinishObserver()
            onFinish()
        }
        player.delegate = LocalAudioPlayerDelegate.shared
        player.play()
    }

    /// 保持している AudioPlayerFinished observer を解放する。
    private func removeAudioFinishObserver() {
        if let observer = audioFinishObserver {
            NotificationCenter.default.removeObserver(observer)
            audioFinishObserver = nil
        }
    }

    private func playWithKokoroTTS() {
        let voice = KokoroPlaybackParams.selectVoice(
            languageCode: UserDefaultsManager.shared.languageSetting,
            storedVoiceRaw: UserDefaultsManager.shared.kokoroVoice
        )
        // Kokoro speed 1.0 = normal; AVSpeechSynthesizer 0.5 = normal → multiply by 2
        let speed = KokoroPlaybackParams.kokoroSpeed(fromSpeechRate: UserDefaultsManager.shared.speechRate)

        Task {
            do {
                let data = try await KokoroTTSClient.liveValue.synthesize(text, voice, speed)
                await MainActor.run {
                    do {
                        audioPlayer?.stop()
                        let player = try AVAudioPlayer(data: data)
                        audioPlayer = player
                        setupAndPlayAudioPlayer(player) {
                            self.isSpeaking = false
                            self.highlightedRange = nil
                            self.store.send(.nowPlaying(.stopPlaying))
                        }
                    } catch {
                        errorLog("[Kokoro] AVAudioPlayer init failed: \(error), falling back to device TTS")
                        playWithDeviceTTS()
                    }
                }
            } catch {
                errorLog("[Kokoro] Synthesis failed: \(error), falling back to device TTS")
                await MainActor.run { playWithDeviceTTS() }
            }
        }
    }

    private func playWithDeviceTTS() {
        infoLog("[Highlight] playWithDeviceTTS called")
        let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
        let rate = UserDefaultsManager.shared.speechRate
        let pitch = UserDefaultsManager.shared.speechPitch
        infoLog("[Highlight] language: \(language), rate: \(rate), pitch: \(pitch)")

        // AVSpeechSynthesizer は長いテキストをサイレントに失敗するため、チャンクに分割して読み上げる
        let chunks = splitIntoChunks(text, maxLength: 4000)
        infoLog("[Highlight] Text split into \(chunks.count) chunks (total \(text.count) chars)")

        Task {
            do {
                for (index, chunk) in chunks.enumerated() {
                    guard isSpeaking else {
                        infoLog("[Highlight] Stopped before chunk \(index)")
                        break
                    }
                    infoLog("[Highlight] Speaking chunk \(index + 1)/\(chunks.count), offset=\(chunk.offset)")
                    let utterance = AVSpeechUtterance(string: chunk.text)
                    // 設定で選ばれた音声（Enhanced/Premium/パーソナルボイス）を優先して使う
                    VoiceResolver.configure(utterance, languageCode: language, rate: rate, pitch: pitch)

                    try await speechSynthesizer.speakWithHighlight(
                        utterance,
                        { range, _ in
                            let offsetRange = NSRange(location: range.location + chunk.offset, length: range.length)
                            DispatchQueue.main.async {
                                self.highlightedRange = offsetRange
                            }
                        },
                        {}
                    )
                }
                infoLog("[Highlight] All chunks completed")
                DispatchQueue.main.async {
                    self.isSpeaking = false
                    self.highlightedRange = nil
                    self.store.send(.nowPlaying(.stopPlaying))
                }
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

    // AVSpeechSynthesizer 用: 文字数ベースで分割（デバイス TTS 向け）
    private func splitIntoChunks(_ text: String, maxLength: Int) -> [(text: String, offset: Int)] {
        guard text.count > maxLength else { return [(text: text, offset: 0)] }

        var chunks: [(text: String, offset: Int)] = []
        var startIndex = text.startIndex
        var offset = 0

        while startIndex < text.endIndex {
            let remaining = text.distance(from: startIndex, to: text.endIndex)
            guard remaining > maxLength else {
                chunks.append((text: String(text[startIndex...]), offset: offset))
                break
            }

            var splitIndex = text.index(startIndex, offsetBy: maxLength)
            let minBack = text.index(startIndex, offsetBy: max(0, maxLength - 500))

            var searchIndex = splitIndex
            while searchIndex > minBack {
                let c = text[searchIndex]
                if c == "\n" || c == "。" || c == "." || c == "!" || c == "?" || c == "！" || c == "？" {
                    if let next = text.index(searchIndex, offsetBy: 1, limitedBy: text.endIndex) {
                        splitIndex = next
                    }
                    break
                }
                searchIndex = text.index(before: searchIndex)
            }

            let chunk = String(text[startIndex..<splitIndex])
            let length = text.distance(from: startIndex, to: splitIndex)
            chunks.append((text: chunk, offset: offset))
            offset += length
            startIndex = splitIndex
        }

        return chunks
    }

    private func stopSpeaking() {
        removeAudioFinishObserver()
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        highlightedRange = nil
        store.send(.nowPlaying(.stopPlaying))
        Task { await speechSynthesizer.stopSpeaking() }
    }

    private func handleSaveButtonTap() {
        // 非課金ユーザーの4000文字制限チェック
        if !UserDefaultsManager.shared.isPremiumUser && text.count > 4_000 {
            showingTextLimitAlert = true
            return
        }
        // プレミアムユーザーの長文は保存せず端末TTSで直接再生
        if text.count > 4_000 {
            isEditMode = false
            speakWithHighlight()
            return
        }
        saveText()
    }

    private func saveText() {
        let finalTitle = String(text.prefix(20))
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
        // クラウドTTS撤去後はすべて端末側の読み上げ。保存し直した時点で
        // 旧 "cloud" レコードも "basic" に寄せ、古い音声ファイルを使わないようにする。
        let ttsMode = "basic"

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

        infoLog("[TTS] Saved as basic TTS, no audio generation")
        hasGeneratedAudio = false
        isEditMode = false
        speakWithHighlight()
    }
}

// MARK: - Local Audio Player Delegate
class LocalAudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = LocalAudioPlayerDelegate()

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
