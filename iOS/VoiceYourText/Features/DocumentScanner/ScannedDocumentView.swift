//
//  ScannedDocumentView.swift
//  VoiceYourText
//
//  Created by Claude on 2026/01/28.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

struct ScannedDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    let text: String
    let imagePaths: [String]
    let fileId: UUID?
    let onSaved: ((UUID) -> Void)? = nil

    @State private var selectedTab: ViewTab = .image
    @State private var currentImageIndex: Int = 0
    @State private var editableText: String = ""
    @State private var isEditingText: Bool = false
    @State private var isSpeaking: Bool = false
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    @FocusState private var isTextEditorFocused: Bool

    enum ViewTab {
        case image
        case text
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
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

                // セグメントコントロール
                Picker("View", selection: $selectedTab) {
                    Text("画像").tag(ViewTab.image)
                    Text("テキスト").tag(ViewTab.text)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                HStack(spacing: 8) {
                    // 再生/停止ボタン（常に表示）
                    Button(action: {
                        if isSpeaking {
                            stopSpeaking()
                        } else {
                            startSpeaking()
                        }
                    }) {
                        Image(systemName: isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .disabled(editableText.isEmpty)

                    // 編集/保存ボタン（テキストタブでのみ表示）
                    if selectedTab == .text {
                        if isEditingText {
                            Button("保存") {
                                saveText()
                            }
                            .disabled(editableText.isEmpty)
                        } else {
                            Button("編集") {
                                isEditingText = true
                                isTextEditorFocused = true
                            }
                        }
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 56)
            .background(Color(UIColor.systemBackground))

            Divider()

            // メインコンテンツ
            if selectedTab == .image {
                imageView
            } else {
                textView
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarHidden(true)
        .onAppear {
            infoLog("ScannedDocumentView onAppear - text length: \(text.count), imagePaths count: \(imagePaths.count)")
            infoLog("ScannedDocumentView imagePaths: \(imagePaths)")
            editableText = text
            // 新規スキャン（fileId == nil）の場合は編集モードで開始
            if fileId == nil {
                isEditingText = true
            }
        }
        .onDisappear {
            stopSpeaking()
        }
    }

    // MARK: - 画像ビュー
    private var imageView: some View {
        VStack(spacing: 0) {
            if !imagePaths.isEmpty, let firstImagePath = imagePaths.first {
                if let image = loadImage(firstImagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("画像を読み込めません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("画像がありません")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - テキストビュー
    private var textView: some View {
        VStack(spacing: 0) {
            if isEditingText {
                // 編集モード
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editableText)
                        .font(.system(size: 20))
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .focused($isTextEditorFocused)

                    // プレースホルダー
                    if editableText.isEmpty {
                        Text("読み上げたいテキストを入力してください...")
                            .foregroundColor(.secondary)
                            .font(.system(size: 20))
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                // 表示モード
                ScrollView {
                    Text(editableText)
                        .font(.system(size: 20))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func startSpeaking() {
        guard !editableText.isEmpty else { return }

        // 既存の音声を停止
        stopSpeaking()

        isSpeaking = true

        let synthesizer = AVSpeechSynthesizer()
        speechSynthesizer = synthesizer

        let coordinator = SpeechCoordinator(onFinish: {
            DispatchQueue.main.async {
                self.isSpeaking = false
            }
        })
        synthesizer.delegate = coordinator

        let utterance = AVSpeechUtterance(string: editableText)

        // 言語設定を取得
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "ja"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.75
        utterance.pitchMultiplier = 1.0

        // 音声設定をアクティブにする
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorLog("Failed to set audio session: \(error)")
        }

        // テキストを選択（ハイライト風）
        store.send(.speechSelected(editableText))

        synthesizer.speak(utterance)
    }

    private func stopSpeaking() {
        isSpeaking = false
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil

        // 全てのAVSpeechSynthesizerを停止
        NotificationCenter.default.post(
            name: NSNotification.Name("StopAllSpeech"),
            object: nil
        )
    }

    private func saveText() {
        let finalTitle = String(editableText.prefix(20))
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english

        // imagePathsをJSON文字列に変換
        var imagePathString: String? = nil
        if !imagePaths.isEmpty {
            if let jsonData = try? JSONEncoder().encode(imagePaths),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                imagePathString = jsonString
            }
        }

        if let fileId = fileId {
            // 既存ファイルを更新
            SpeechTextRepository.shared.updateSpeechText(
                id: fileId,
                title: finalTitle,
                text: editableText
            )
        } else {
            // 新規作成
            SpeechTextRepository.shared.insert(
                title: finalTitle,
                text: editableText,
                languageSetting: languageSetting,
                fileType: "scan",
                imagePath: imagePathString
            )
        }

        // 編集モードを終了
        isEditingText = false
        isTextEditorFocused = false

        // stateを更新してリストを再取得
        store.send(.onAppear)
    }

    private func loadImage(_ imagePath: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let scansDirectory = documentsURL.appendingPathComponent("scans", isDirectory: true)
        let imageURL = scansDirectory.appendingPathComponent(imagePath)

        debugLog("Loading image from: \(imageURL.path)")
        debugLog("File exists: \(fileManager.fileExists(atPath: imageURL.path))")

        if let imageData = try? Data(contentsOf: imageURL) {
            debugLog("Image loaded successfully, size: \(imageData.count) bytes")
            return UIImage(data: imageData)
        }
        errorLog("Failed to load image from: \(imageURL.path)")
        return nil
    }
}

// MARK: - Speech Coordinator
private class SpeechCoordinator: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}

#Preview {
    ScannedDocumentView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        text: "スキャンされたテキストのサンプル\nこれは複数行のテキストです。\n音声で読み上げることができます。",
        imagePaths: [],
        fileId: nil
    )
}
