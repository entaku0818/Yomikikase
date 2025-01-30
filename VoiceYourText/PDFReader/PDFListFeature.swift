//
//  PDFListFeature.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2025/01/30.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import ComposableArchitecture
// PDFListFeature.swift
struct PDFListFeature: Reducer {
    struct State: Equatable {
        var pdfFiles: [PDFFile] = []
        var showingFilePicker = false
    }

    struct PDFFile: Equatable, Identifiable {
        let id: UUID = UUID()
        let url: URL
        let fileName: String
        let createdAt: Date
    }

    enum Action: Equatable {
        case loadPDFFiles
        case pdfFilesLoaded([PDFFile])
        case showFilePicker
        case selectPDFFile(URL)
        case deletePDFFile(PDFFile)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadPDFFiles:
                // アプリのドキュメントディレクトリからPDFファイルを読み込む
                return .run { send in
                    let files = try await loadPDFFilesFromDocuments()
                    await send(.pdfFilesLoaded(files))
                }

            case let .pdfFilesLoaded(files):
                state.pdfFiles = files
                return .none

            case .showFilePicker:
                state.showingFilePicker = true
                return .none

            case let .selectPDFFile(url):
                // ファイルをドキュメントディレクトリにコピー
                return .run { send in
                    let newFile = try await savePDFFile(from: url)
                    await send(.loadPDFFiles)
                }

            case let .deletePDFFile(file):
                // ファイルの削除
                return .run { send in
                    try await deletePDFFile(file)
                    await send(.loadPDFFiles)
                }
            }
        }
    }

    private func loadPDFFilesFromDocuments() async throws -> [PDFFile] {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: documentDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .compactMap { url -> PDFFile? in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let creationDate = attributes[.creationDate] as? Date else {
                    return nil
                }
                return PDFFile(
                    url: url,
                    fileName: url.lastPathComponent,
                    createdAt: creationDate
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func savePDFFile(from sourceURL: URL) async throws -> PDFFile {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.cannotCreateFile)
        }

        let destinationURL = documentDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let creationDate = attributes[.creationDate] as? Date ?? Date()

        return PDFFile(
            url: destinationURL,
            fileName: destinationURL.lastPathComponent,
            createdAt: creationDate
        )
    }

    private func deletePDFFile(_ file: PDFFile) async throws {
        try FileManager.default.removeItem(at: file.url)
    }
}

// PDFListView.swift
struct PDFListView: View {
    let store: StoreOf<PDFListFeature>
    @ObservedObject var viewStore: ViewStoreOf<PDFListFeature>

    init(store: StoreOf<PDFListFeature>) {
        self.store = store
        self.viewStore = ViewStore(self.store, observe: { $0 })
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(viewStore.pdfFiles) { file in
                    VStack(alignment: .leading) {
                        Text(file.fileName)
                            .font(.headline)
                        Text(file.createdAt.formatted())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let file = viewStore.pdfFiles[index]
                        viewStore.send(.deletePDFFile(file))
                    }
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
                    send: { _ in .showFilePicker }
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
        }
        .onAppear {
            viewStore.send(.loadPDFFiles)
        }
    }
}
