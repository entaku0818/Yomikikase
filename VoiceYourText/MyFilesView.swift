//
//  MyFilesView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture

struct MyFilesView: View {
    @State private var textFiles: [SavedTextFile] = []
    @State private var pdfFiles: [SavedPDFFile] = []
    @State private var searchText = ""
    @State private var showingSubscription = false
    let store: StoreOf<Speeches>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索とメニューボタン
                HStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // ファイルリスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(combinedFiles) { file in
                            if file.type == .text {
                                NavigationLink(destination: TextInputView(store: store)) {
                                    FileItemView(file: file)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                FileItemView(file: file)
                                    .onTapGesture {
                                        // PDFファイルを開く処理
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // プレミアム広告（無料ユーザーの場合）
                    if !UserDefaultsManager.shared.isPremiumUser {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                Text("PDFファイル: \(maxFreePDFFiles)の\(pdfFiles.count)ファイル")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Spacer()
                            }
                            
                            Text("アップグレードでPDFファイルをさらに追加")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                showingSubscription = true
                            }) {
                                Text("アップグレード")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 100)
                }
                
            }
            .navigationTitle("マイファイル")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .onAppear {
            loadFiles()
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
                progress: 100,
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
                progress: Int.random(in: 0...100),
                date: pdfFile.createdAt,
                type: .pdf
            )
        })
        
        return files.sorted { $0.date > $1.date }
    }
    
    private var maxFreePDFFiles: Int { 3 }
    
    
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
        
        // PDFファイルの読み込み（実装は後で）
        // pdfFiles = loadPDFFiles()
    }
}

struct FileItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let progress: Int
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
                    Text("\(file.progress)%")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
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
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    MyFilesView(store: Store(initialState: Speeches.State(speechList: [], currentText: "")) {
        Speeches()
    })
}