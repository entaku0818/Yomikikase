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
    let store: StoreOf<Speeches>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // ファイルリスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(combinedFiles) { file in
                            if file.type == .text {
                                NavigationLink(destination: TextInputView(store: store, initialText: getTextForFile(file.id), fileId: file.id)) {
                                    FileItemView(file: file)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("削除", role: .destructive) {
                                        fileToDelete = file
                                        showingDeleteAlert = true
                                    }
                                }
                            } else if file.type == .pdf {
                                NavigationLink(destination: PDFReaderView(
                                    store: Store(
                                        initialState: PDFReaderFeature.State(currentPDFURL: getPDFURLForFile(file.id))
                                    ) {
                                        PDFReaderFeature()
                                    }
                                )) {
                                    FileItemView(file: file)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("削除", role: .destructive) {
                                        fileToDelete = file
                                        showingDeleteAlert = true
                                    }
                                }
                            } else {
                                FileItemView(file: file)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
                
                // 広告バナー（最下部）
                if !UserDefaultsManager.shared.isPremiumUser {
                    AdmobBannerView()
                        .frame(height: 50)
                }
            }
            .navigationTitle("マイファイル")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
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
    }
    
    private var combinedFiles: [FileItem] {
        var files: [FileItem] = []
        
        // テキストファイルを追加
        files.append(contentsOf: textFiles.map { textFile in
            FileItem(
                id: textFile.id,
                title: textFile.title,
                subtitle: "あああああああ",
                date: textFile.updatedAt,
                type: .text
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
                updatedAt: speech.updatedAt
            )
        }
        
        // PDFファイルの読み込み
        loadPDFFiles()
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
            print("Error loading PDF files: \(error.localizedDescription)")
        }
    }
    
    private func getTextForFile(_ fileId: UUID) -> String {
        return textFiles.first { $0.id == fileId }?.text ?? ""
    }
    
    private func getPDFURLForFile(_ fileId: UUID) -> URL? {
        return pdfFiles.first { $0.id == fileId }?.url
    }
    
    private func deleteTextFile(_ fileId: UUID) {
        // Core Dataから削除
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
            print("Error deleting PDF file: \(error.localizedDescription)")
        }
    }
}

struct FileItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let date: Date
    let type: FileType
    
    enum FileType {
        case text, pdf
    }
}

struct SavedTextFile: Identifiable {
    let id: UUID
    let title: String
    let text: String
    let createdAt: Date
    let updatedAt: Date
}

struct SavedPDFFile: Identifiable {
    let id: UUID
    let fileName: String
    let url: URL
    let createdAt: Date
}

struct FileItemView: View {
    let file: FileItem
    
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
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // ファイルアイコン
            Image(systemName: file.type == .pdf ? "doc.richtext.fill" : "doc.text.fill")
                .font(.system(size: 28))
                .foregroundColor(file.type == .pdf ? .red : .blue)
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