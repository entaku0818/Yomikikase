//
//  MyFilesView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import Foundation

struct MyFilesView: View {
    @State private var textFiles: [SavedTextFile] = []
    @State private var pdfFiles: [SavedPDFFile] = []
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var fileToDelete: FileItem?
    @State private var selectedTextFile: SavedTextFile?
    @State private var selectedPDFFile: SavedPDFFile?
    let store: StoreOf<Speeches>

    @Dependency(\.audioAPI) var audioAPI
    @Dependency(\.audioFileManager) var audioFileManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // ファイルリスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(combinedFiles) { file in
                            if file.type == .text {
                                Button {
                                    if let textFile = textFiles.first(where: { $0.id == file.id }) {
                                        selectedTextFile = textFile
                                    }
                                } label: {
                                    FileItemView(file: file, onDelete: {
                                        fileToDelete = file
                                        showingDeleteAlert = true
                                    })
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else if file.type == .epub {
                                Button {
                                    if let textFile = textFiles.first(where: { $0.id == file.id }) {
                                        selectedTextFile = textFile
                                    }
                                } label: {
                                    FileItemView(file: file, onDelete: {
                                        fileToDelete = file
                                        showingDeleteAlert = true
                                    })
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else if file.type == .pdf {
                                Button {
                                    if let pdfFile = pdfFiles.first(where: { $0.id == file.id }) {
                                        selectedPDFFile = pdfFile
                                    }
                                } label: {
                                    FileItemView(file: file, onDelete: {
                                        fileToDelete = file
                                        showingDeleteAlert = true
                                    })
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                FileItemView(file: file, onDelete: nil)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
                .refreshable {
                    loadFiles()
                }
                
                // 広告バナー（最下部）
                if !UserDefaultsManager.shared.isPremiumUser {
                    AdmobBannerView()
                        .frame(height: 50)
                }
            }
            .navigationTitle("マイファイル")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: DeletedItemsView(
                        store: Store(initialState: DeletedItemsFeature.State()) {
                            DeletedItemsFeature()
                        }
                    )) {
                        Image(systemName: "trash")
                            .font(.system(size: 17))
                    }
                }
            }
        }
        .onAppear {
            loadFiles()
            // 7日以上前の削除済みアイテムをクリーンアップ
            SpeechTextRepository.shared.cleanupOldDeletedItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TTSJobCompleted"))) { _ in
            loadFiles()
        }
        .alert("削除の確認", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {
                fileToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let file = fileToDelete {
                    if file.type == .text {
                        deleteTextFile(file.id)
                    } else if file.type == .pdf {
                        deletePDFFile(file.id)
                    }
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("「\(file.title)」を削除しますか？")
            }
        }
        .fullScreenCover(item: $selectedTextFile) { textFile in
            TextInputView(
                store: store,
                initialText: textFile.text,
                fileId: textFile.id
            )
        }
        .fullScreenCover(item: $selectedPDFFile) { pdfFile in
            PDFReaderView(
                store: Store(
                    initialState: PDFReaderFeature.State(currentPDFURL: pdfFile.url)
                ) {
                    PDFReaderFeature()
                },
                parentStore: store
            )
        }
    }

    private var combinedFiles: [FileItem] {
        var files: [FileItem] = []
        
        // テキストファイルを追加
        files.append(contentsOf: textFiles.map { textFile in
            let fileType: FileItem.FileType = textFile.fileType == "epub" ? .epub : .text
            return FileItem(
                id: textFile.id,
                title: textFile.title,
                subtitle: textFile.fileType,
                date: textFile.updatedAt,
                type: fileType,
                isProcessing: UserDefaultsManager.shared.pendingJobId(for: textFile.id) != nil
            )
        })
        
        // PDFファイルを追加
        files.append(contentsOf: pdfFiles.map { pdfFile in
            FileItem(
                id: pdfFile.id,
                title: pdfFile.fileName,
                subtitle: pdfFile.fileName,
                date: pdfFile.createdAt,
                type: .pdf
            )
        })
        
        return files.sorted { $0.date > $1.date }
    }
    
    
    
    private func loadFiles() {
        // テキストファイルの読み込み
        let languageCode = UserDefaultsManager.shared.languageSetting ?? "en"
        let languageSetting = SpeechTextRepository.LanguageSetting(rawValue: languageCode) ?? .english
        let speeches = SpeechTextRepository.shared.fetchAllSpeechText(language: languageSetting)

        textFiles = speeches.filter { !$0.isDefault }.map { speech in
            SavedTextFile(
                id: speech.id,
                title: speech.title,
                text: speech.text,
                createdAt: speech.createdAt,
                updatedAt: speech.updatedAt,
                fileType: speech.fileType ?? "text"
            )
        }

        // PDFファイルの読み込み
        loadPDFFiles()

        // pending ジョブがあればサーバーの状態を確認して自動解除
        checkPendingJobs()
    }

    private func checkPendingJobs() {
        let pendingFiles = textFiles.filter {
            UserDefaultsManager.shared.pendingJobId(for: $0.id) != nil
        }
        for file in pendingFiles {
            guard let jobId = UserDefaultsManager.shared.pendingJobId(for: file.id) else { continue }
            Task {
                do {
                    let status = try await audioAPI.getJobStatus(jobId)
                    guard status.status == "completed" || status.status == "failed" else { return }

                    if status.status == "completed",
                       let audioUrlString = status.audioUrl,
                       let audioURL = URL(string: audioUrlString) {
                        let localURL = try await audioFileManager.downloadAudio(audioURL, file.id.uuidString)
                        if let timepoints = status.timepoints, !timepoints.isEmpty {
                            let timepointsURL = localURL.deletingPathExtension().appendingPathExtension("json")
                            let data = try JSONEncoder().encode(timepoints)
                            try data.write(to: timepointsURL)
                        }
                    }

                    await MainActor.run {
                        UserDefaultsManager.shared.clearPendingJob(fileId: file.id)
                        loadFiles()
                    }
                } catch {
                    // ネットワーク失敗時はスピナーを残す（次回 onAppear で再試行）
                }
            }
        }
    }
    
    private func loadPDFFiles() {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            pdfFiles = fileURLs
                .filter { $0.pathExtension.lowercased() == "pdf" }
                .compactMap { url -> SavedPDFFile? in
                    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                          let creationDate = attributes[.creationDate] as? Date else {
                        return nil
                    }
                    return SavedPDFFile(
                        id: UUID(),
                        fileName: url.lastPathComponent,
                        url: url,
                        createdAt: creationDate
                    )
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorLog("Error loading PDF files: \(error.localizedDescription)")
        }
    }
    
    private func getTextForFile(_ fileId: UUID) -> String {
        return textFiles.first { $0.id == fileId }?.text ?? ""
    }
    
    private func getPDFURLForFile(_ fileId: UUID) -> URL? {
        return pdfFiles.first { $0.id == fileId }?.url
    }
    
    private func deleteTextFile(_ fileId: UUID) {
        // ソフトデリート（7日後に完全削除）
        SpeechTextRepository.shared.delete(id: fileId)
        // ローカルリストから削除
        textFiles.removeAll { $0.id == fileId }
    }
    
    private func deletePDFFile(_ fileId: UUID) {
        guard let pdfFile = pdfFiles.first(where: { $0.id == fileId }) else { return }
        
        do {
            // ファイルシステムから削除
            try FileManager.default.removeItem(at: pdfFile.url)
            // ローカルリストから削除
            pdfFiles.removeAll { $0.id == fileId }
        } catch {
            errorLog("Error deleting PDF file: \(error.localizedDescription)")
        }
    }
}

struct FileItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let date: Date
    let type: FileType
    var isProcessing: Bool = false

    enum FileType {
        case text, pdf, epub
    }
}

struct SavedTextFile: Identifiable {
    let id: UUID
    let title: String
    let text: String
    let createdAt: Date
    let updatedAt: Date
    var fileType: String = "text"
}

struct SavedPDFFile: Identifiable {
    let id: UUID
    let fileName: String
    let url: URL
    let createdAt: Date
}

struct FileItemView: View {
    let file: FileItem
    var onDelete: (() -> Void)?

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(file.date) {
            formatter.dateFormat = "今日"
        } else {
            formatter.dateFormat = "M月d日"
        }
        return formatter
    }

    private var fileTypeText: String {
        switch file.type {
        case .text: return "txt"
        case .pdf: return "pdf"
        case .epub: return "epub"
        }
    }

    private var fileIconName: String {
        switch file.type {
        case .text: return "doc.text.fill"
        case .pdf: return "doc.richtext.fill"
        case .epub: return "books.vertical.fill"
        }
    }

    private var fileIconColor: Color {
        switch file.type {
        case .text: return .blue
        case .pdf: return .red
        case .epub: return .brown
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // ファイルアイコン
            Image(systemName: fileIconName)
                .font(.system(size: 28))
                .foregroundColor(fileIconColor)
                .frame(width: 48, height: 48)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)

                HStack {
                    Text(dateFormatter.string(from: file.date))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text(fileTypeText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if file.isProcessing {
                ProgressView()
                    .scaleEffect(0.85)
                    .frame(width: 32, height: 32)
            } else if let onDelete = onDelete {
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    MyFilesView(store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
        Speeches()
    })
}