//
//  ScannedDocumentView.swift
//  VoiceYourText
//
//  Created by Claude on 2026/01/28.
//

import SwiftUI
import ComposableArchitecture

struct ScannedDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    let text: String
    let imagePaths: [String]
    let fileId: UUID?

    @State private var selectedTab: ViewTab = .image
    @State private var currentImageIndex: Int = 0
    @State private var editableText: String = ""
    @State private var isEditingText: Bool = false
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

                // 編集/保存ボタン（テキストタブでのみ表示）
                if selectedTab == .text {
                    if isEditingText {
                        Button("保存") {
                            saveText()
                        }
                        .disabled(editableText.isEmpty)
                        .padding(.trailing, 16)
                    } else {
                        Button("編集") {
                            isEditingText = true
                            isTextEditorFocused = true
                        }
                        .padding(.trailing, 16)
                    }
                } else {
                    // プレースホルダー（対称性のため）
                    Color.clear
                        .frame(width: 52, height: 44)
                }
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
            editableText = text
            // 新規スキャン（fileId == nil）の場合は編集モードで開始
            if fileId == nil {
                isEditingText = true
            }
        }
    }

    // MARK: - 画像ビュー
    private var imageView: some View {
        VStack(spacing: 0) {
            if !imagePaths.isEmpty {
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(imagePaths.enumerated()), id: \.offset) { index, imagePath in
                        if let image = loadImage(imagePath) {
                            ScrollView([.horizontal, .vertical]) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            }
                            .tag(index)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("画像を読み込めません")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // ページ情報
                if imagePaths.count > 1 {
                    Text("ページ \(currentImageIndex + 1) / \(imagePaths.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
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

#Preview {
    ScannedDocumentView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        text: "スキャンされたテキストのサンプル",
        imagePaths: [],
        fileId: nil
    )
}
