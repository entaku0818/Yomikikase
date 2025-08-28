//
//  SimplePDFPickerView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/07/01.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.app.pdfreader",
    category: "PDFPicker"
)

struct SimplePDFPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var showingPremiumAlert = false
    @State private var showingSubscription = false
    @State private var isProcessing = false
    
    // 最大登録可能なPDFファイル数 (無料版)
    private let maxFreePDFCount = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                
                Spacer()
                
                // PDFアイコン
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .frame(width: 120, height: 120)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
                
                VStack(spacing: 16) {
                    Text("PDFファイルを追加")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("読み上げたいPDFファイルを選択してください")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // PDFファイル選択ボタン
                Button(action: {
                    if hasReachedFreeLimit() {
                        showingPremiumAlert = true
                    } else {
                        showingFilePicker = true
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        Text(isProcessing ? "処理中..." : "PDFファイルを選択")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 40)
                
                // 無料ユーザーの場合に登録制限の表示
                if !UserDefaultsManager.shared.isPremiumUser {
                    VStack(spacing: 8) {
                        Text("無料版: \(getCurrentPDFCount())/\(maxFreePDFCount)ファイル")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("プレミアムにアップグレード") {
                            showingSubscription = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // 広告バナー
                if !UserDefaultsManager.shared.isPremiumUser {
                    AdmobBannerView()
                        .frame(height: 50)
                }
            }
            .navigationTitle("PDF追加")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("プレミアム機能が必要です", isPresented: $showingPremiumAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("詳細を見る") {
                    showingSubscription = true
                }
            } message: {
                Text("無料版では最大\(maxFreePDFCount)つまでのPDFファイルを登録できます。プレミアム版にアップグレードすると、無制限にPDFファイルを登録できます。")
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        }
    }
    
    private func hasReachedFreeLimit() -> Bool {
        return !UserDefaultsManager.shared.isPremiumUser && getCurrentPDFCount() >= maxFreePDFCount
    }
    
    private func getCurrentPDFCount() -> Int {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return fileURLs.filter { $0.pathExtension.lowercased() == "pdf" }.count
        } catch {
            return 0
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isProcessing = true
            Task {
                do {
                    try await savePDFFile(from: url)
                    await MainActor.run {
                        isProcessing = false
                        // マイファイルページに遷移
                        navigateToMyFiles()
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        logger.error("PDF保存エラー: \(error.localizedDescription)")
                    }
                }
            }
        case .failure(let error):
            logger.error("ファイル選択エラー: \(error.localizedDescription)")
        }
    }
    
    private func savePDFFile(from sourceURL: URL) async throws {
        logger.info("PDF保存開始: \(sourceURL.absoluteString)")
        
        // Security Scoped Resource を取得
        let isSecured = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.cannotCreateFile)
        }
        
        let destinationURL = documentDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager.default
                let coordinator = NSFileCoordinator()
                var error: NSError?
                
                coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &error) { secureURL in
                    do {
                        // 既に存在する場合は削除
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }
                        
                        // ファイルのデータを取得して書き込む
                        let fileData = try Data(contentsOf: secureURL)
                        try fileData.write(to: destinationURL)
                        
                        logger.info("PDF保存完了: \(destinationURL.absoluteString)")
                        continuation.resume()
                    } catch {
                        logger.error("PDF保存失敗: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
                
                if let coordinatorError = error {
                    continuation.resume(throwing: coordinatorError)
                }
            }
        }
    }
    
    private func navigateToMyFiles() {
        // Dismissして前の画面に戻る（想定：TabViewでMyFilesタブに切り替える）
        dismiss()
    }
}

#Preview {
    SimplePDFPickerView()
}