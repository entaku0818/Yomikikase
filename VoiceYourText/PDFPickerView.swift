//
//  PDFPickerView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import UniformTypeIdentifiers

struct PDFPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // アイコン
                Image(systemName: "doc.richtext")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                // タイトルと説明
                VStack(spacing: 12) {
                    Text("PDFファイルを選択")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("読み上げたいPDFファイルを選択してください")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // ファイル選択ボタン
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("ファイルを選択")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // キャンセルボタン
                Button(action: {
                    dismiss()
                }) {
                    Text("キャンセル")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("PDF選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handlePDFSelection(url: url)
                }
            case .failure(let error):
                print("PDF selection failed: \(error)")
            }
        }
    }
    
    private func handlePDFSelection(url: URL) {
        // PDFファイルの処理
        // 後でPDFListFeatureと統合
        dismiss()
    }
}

#Preview {
    PDFPickerView()
}