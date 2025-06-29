//
//  PDFPickerView.swift
//  VoiceYourText
//
//  Created by Claude on 2025/06/29.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct PDFPickerView: View {
    let store = Store(
        initialState: PDFListFeature.State()
    ) {
        PDFListFeature()
    }
    @ObservedObject var viewStore: ViewStoreOf<PDFListFeature>
    @State private var showingSubscription = false

    init() {
        self.store = Store(
            initialState: PDFListFeature.State()
        ) {
            PDFListFeature()
        }
        self.viewStore = ViewStore(self.store, observe: { $0 })
    }

    var body: some View {
        VStack {
            List {
                ForEach(viewStore.pdfFiles) { file in
                    NavigationLink(destination: PDFReaderView(
                        store: Store(
                            initialState: PDFReaderFeature.State(currentPDFURL: file.url)
                        ) {
                            PDFReaderFeature()
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(file.fileName)
                                .font(.headline)
                            Text(file.createdAt.formatted())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let file = viewStore.pdfFiles[index]
                        viewStore.send(.deletePDFFile(file))
                    }
                }
            }
            
            // 無料ユーザーの場合に登録制限の表示
            if !UserDefaultsManager.shared.isPremiumUser {
                HStack {
                    Text("無料版: \(viewStore.pdfFiles.count)/\(viewStore.maxFreePDFCount)ファイル")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("プレミアムにアップグレード") {
                        showingSubscription = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            
            // 広告バナーを追加
            if !UserDefaultsManager.shared.isPremiumUser {
                AdmobBannerView().frame(width: .infinity, height: 50)
            }
        }
        .navigationTitle("PDFファイル")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewStore.send(.showFilePicker) }) {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: viewStore.binding(
                get: \.showingFilePicker,
                send: { value in value ? .showFilePicker : .hideFilePicker }
            ),
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewStore.send(.selectPDFFile(url))
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
        .alert("プレミアム機能が必要です", isPresented: viewStore.binding(
            get: \.showingPremiumAlert,
            send: { _ in .hidePremiumAlert }
        )) {
            Button("キャンセル", role: .cancel) { }
            Button("詳細を見る") {
                showingSubscription = true
            }
        } message: {
            Text("無料版では最大\(viewStore.maxFreePDFCount)つまでのPDFファイルを登録できます。プレミアム版にアップグレードすると、無制限にPDFファイルを登録できます。")
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .onAppear {
            viewStore.send(.loadPDFFiles)
        }
    }
}

#Preview {
    NavigationStack {
        PDFPickerView()
    }
}