//
//  HomeView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import Dependencies

struct HomeView: View {
    let store: Store<Speeches.State, Speeches.Action>
    let onDevelopmentFeature: (String) -> Void

    @State private var showingTextFilePicker = false
    @State private var importedText: String = ""
    @State private var showingImportedTextView = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var showingPremiumAlert = false
    @State private var showingSubscription = false
    @State private var showingNewTextView = false
    @State private var showingDocumentScanner = false
    @State private var scannedDocument: ScannedDocument? = nil
    @State private var showingScanError = false
    @State private var scanErrorMessage = ""
    @State private var selectedSpeech: Speeches.Speech? = nil
    @State private var showingFileViewer = false

    struct ScannedDocument: Identifiable {
        let id = UUID()
        let text: String
        let imagePaths: [String]
    }

    @Dependency(\.textFileImport) var textFileImport
    @Dependency(\.analytics) var analytics

    var body: some View {
        NavigationStack {
            WithViewStore(store, observe: { $0 }) { viewStore in
                ScrollView {
                    VStack(spacing: 20) {
                        // 機能ボタングリッド
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            
                            // テキスト（有効）
                            Button {
                                if FileLimitsManager.hasReachedFreeLimit() {
                                    showingPremiumAlert = true
                                } else {
                                    showingNewTextView = true
                                }
                            } label: {
                                createButtonContent(
                                    icon: "doc.text.fill",
                                    iconColor: .blue,
                                    title: "テキスト",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // PDF（有効）
                            NavigationLink(destination: SimplePDFPickerView()) {
                                createButtonContent(
                                    icon: "doc.richtext.fill",
                                    iconColor: .red,
                                    title: "PDF",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // TXTファイル（有効）
                            Button {
                                if FileLimitsManager.hasReachedFreeLimit() {
                                    showingPremiumAlert = true
                                } else {
                                    showingTextFilePicker = true
                                }
                            } label: {
                                createButtonContent(
                                    icon: "doc.plaintext.fill",
                                    iconColor: .purple,
                                    title: "TXTファイル",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Googleドライブ（無効）
                            createButtonCard(
                                icon: "externaldrive.fill",
                                iconColor: .green,
                                title: "Gドライブ",
                                isEnabled: false,
                                action: { onDevelopmentFeature("Googleドライブ") }
                            )
                            
                            // Kindle（無効）
                            createButtonCard(
                                icon: "book.fill",
                                iconColor: .orange,
                                title: "Kindle",
                                isEnabled: false,
                                action: { onDevelopmentFeature("Kindle") }
                            )
                            
                            // 本（無効）
                            createButtonCard(
                                icon: "books.vertical.fill",
                                iconColor: .brown,
                                title: "本",
                                isEnabled: false,
                                action: { onDevelopmentFeature("本") }
                            )
                            
                            // スキャン（有効）
                            Button {
                                analytics.logEvent("scan_button_tapped", ["screen": "home"])
                                if FileLimitsManager.hasReachedFreeLimit() {
                                    showingPremiumAlert = true
                                } else if !DocumentScannerView.isAvailable {
                                    scanErrorMessage = "この機能はお使いのデバイスではサポートされていません"
                                    showingScanError = true
                                } else {
                                    showingDocumentScanner = true
                                }
                            } label: {
                                createButtonContent(
                                    icon: "camera.fill",
                                    iconColor: .gray,
                                    title: "スキャン",
                                    isEnabled: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // リンク（無効）
                            createButtonCard(
                                icon: "link",
                                iconColor: .cyan,
                                title: "リンク",
                                isEnabled: false,
                                action: { onDevelopmentFeature("リンク") }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // 最近のファイル
                        if !viewStore.speechList.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("最近のファイル")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(viewStore.speechList.prefix(3))) { speech in
                                        HStack {
                                            // スキャンファイルはカメラアイコン、それ以外はテキストアイコン
                                            let iconName = speech.fileType == "scan" ? "camera.fill" : "doc.text.fill"
                                            let iconColor: Color = speech.fileType == "scan" ? .gray : .blue

                                            Image(systemName: iconName)
                                                .font(.system(size: 20))
                                                .foregroundColor(iconColor)
                                                .frame(width: 32, height: 32)
                                                .background(iconColor.opacity(0.1))
                                                .cornerRadius(6)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(speech.title)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .lineLimit(1)
                                                
                                                Text(speech.updatedAt, style: .date)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()

                                            Button {
                                                selectedSpeech = speech
                                                showingFileViewer = true
                                                viewStore.send(.speechSelected(speech.text))
                                            } label: {
                                                Image(systemName: "play.circle")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // 広告バナー（最下部）
                if !UserDefaultsManager.shared.isPremiumUser {
                    AdmobBannerView()
                        .frame(height: 50)
                }
            }
            .navigationTitle("Voice Narrator")
            .navigationBarTitleDisplayMode(.large)
            .fileImporter(
                isPresented: $showingTextFilePicker,
                allowedContentTypes: [UTType.plainText, UTType.utf8PlainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            do {
                                importedText = try await textFileImport.readTextFile(url)
                                showingImportedTextView = true
                            } catch {
                                importErrorMessage = error.localizedDescription
                                showingImportError = true
                            }
                        }
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                    showingImportError = true
                }
            }
            .navigationDestination(isPresented: $showingImportedTextView) {
                TextInputView(store: store, initialText: importedText, fileId: nil)
            }
            .alert("エラー", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
            }
            .alert("プレミアム機能が必要です", isPresented: $showingPremiumAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("詳細を見る") {
                    showingSubscription = true
                }
            } message: {
                Text("無料版では最大\(FileLimitsManager.maxFreeFileCount)個までのファイル（PDF・テキスト合計）を登録できます。プレミアム版にアップグレードすると、無制限にファイルを登録できます。")
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .fullScreenCover(isPresented: $showingNewTextView) {
                TextInputView(store: store, initialText: "", fileId: nil)
            }
            .fullScreenCover(isPresented: $showingDocumentScanner, onDismiss: {
                // dismissが完了したらログを出力
                infoLog("DocumentScanner dismissed")
            }) {
                DocumentScannerView(
                    onTextExtracted: { text, imagePaths in
                        infoLog("HomeView received onTextExtracted - text length: \(text.count), imagePaths count: \(imagePaths.count)")
                        infoLog("HomeView imagePaths: \(imagePaths)")

                        // スキャナーを閉じる
                        showingDocumentScanner = false

                        // dismissが完了してからデータをセットしてビューを表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            infoLog("Setting scannedDocument with text length: \(text.count), imagePaths: \(imagePaths)")
                            scannedDocument = ScannedDocument(text: text, imagePaths: imagePaths)
                        }

                        analytics.logEvent("scan_completed", [
                            "text_length": text.count,
                            "page_count": imagePaths.count,
                            "screen": "home"
                        ])
                    },
                    onError: { error in
                        scanErrorMessage = error
                        showingScanError = true
                        analytics.logEvent("scan_error", [
                            "error": error,
                            "screen": "home"
                        ])
                    }
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $scannedDocument) { document in
                ScannedDocumentView(
                    store: store,
                    text: document.text,
                    imagePaths: document.imagePaths,
                    fileId: nil
                )
            }
            .alert("スキャンエラー", isPresented: $showingScanError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(scanErrorMessage)
            }
            .fullScreenCover(isPresented: $showingFileViewer) {
                FileViewerContainer(speech: selectedSpeech, store: store)
            }
        }
    }
    
    @ViewBuilder
    private func createButtonContent(
        icon: String,
        iconColor: Color,
        title: String,
        isEnabled: Bool
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(isEnabled ? iconColor : Color.gray.opacity(0.5))
                .frame(width: 50, height: 50)
                .background((isEnabled ? iconColor : Color.gray).opacity(0.1))
                .cornerRadius(12)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(isEnabled ? Color(.systemBackground) : Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(isEnabled ? 0.05 : 0.02), radius: isEnabled ? 4 : 2, x: 0, y: isEnabled ? 2 : 1)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    @ViewBuilder
    private func createButtonCard(
        icon: String,
        iconColor: Color,
        title: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isEnabled ? iconColor : Color.gray.opacity(0.5))
                    .frame(width: 50, height: 50)
                    .background((isEnabled ? iconColor : Color.gray).opacity(0.1))
                    .cornerRadius(12)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isEnabled ? Color(.systemBackground) : Color(.systemGray6))
            .cornerRadius(16)
            .shadow(color: .black.opacity(isEnabled ? 0.05 : 0.02), radius: isEnabled ? 4 : 2, x: 0, y: isEnabled ? 2 : 1)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentItemView: View {
    let title: String
    let subtitle: String
    let date: Date
    let progress: Int
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        HStack {
            // ファイルアイコン
            Image(systemName: subtitle == "PDF" ? "doc.richtext.fill" : "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(subtitle == "PDF" ? .red : .blue)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                HStack {
                    Text("\(progress)%")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(subtitle.lowercased())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - File Viewer Container
struct FileViewerContainer: View {
    let speech: Speeches.Speech?
    let store: Store<Speeches.State, Speeches.Action>

    var body: some View {
        Group {
            if let speech = speech {
                if speech.fileType == "scan", let imagePathString = speech.imagePath {
                    // スキャンファイルの場合
                    scanFileView(speech: speech, imagePathString: imagePathString)
                } else {
                    // 通常のテキストファイル
                    TextInputView(store: store, initialText: speech.text, fileId: speech.id)
                }
            }
        }
    }

    @ViewBuilder
    private func scanFileView(speech: Speeches.Speech, imagePathString: String) -> some View {
        if let imagePathsData = imagePathString.data(using: .utf8),
           let imagePaths = try? JSONDecoder().decode([String].self, from: imagePathsData) {
            ScannedDocumentView(
                store: store,
                text: speech.text,
                imagePaths: imagePaths,
                fileId: speech.id
            )
            .onAppear {
                debugLog("Loading scan file with imagePath: \(imagePathString)")
                debugLog("Decoded \(imagePaths.count) image paths: \(imagePaths)")
            }
        } else {
            TextInputView(store: store, initialText: speech.text, fileId: speech.id)
                .onAppear {
                    errorLog("Failed to decode imagePaths JSON: \(imagePathString)")
                }
        }
    }
}

#Preview {
    HomeView(
        store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
            Speeches()
        },
        onDevelopmentFeature: { _ in }
    )
}