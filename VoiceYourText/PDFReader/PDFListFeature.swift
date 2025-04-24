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
import os.log
// PDFListFeature.swift

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.app.pdfreader",
    category: "PDFReader"
)

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
        case hideFilePicker
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

            case .hideFilePicker:
                state.showingFilePicker = false
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
        logger.info("Starting PDF file save operation")
        logger.info("Source URL: \(sourceURL.absoluteString)")

        // Security Scoped Resource を取得
        let isSecured = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("❌ Failed to get document directory")
            throw URLError(.cannotCreateFile)
        }

        let destinationURL = documentDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        logger.info("Destination URL: \(destinationURL.absoluteString)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager.default

                // ファイルを安全に読み込むための `NSFileCoordinator`
                let coordinator = NSFileCoordinator()
                var error: NSError?

                coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &error) { secureURL in
                    do {
                        // 既に存在する場合は削除
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                            logger.info("✅ Removed existing file at destination")
                        }

                        // ✅ ファイルのデータを取得して書き込む（copyItem ではなく Data で確実に取得）
                        let fileData = try Data(contentsOf: secureURL)
                        try fileData.write(to: destinationURL)
                        logger.info("✅ Successfully copied file to destination")

                        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date()

                        let pdfFile = PDFFile(
                            url: destinationURL,
                            fileName: destinationURL.lastPathComponent,
                            createdAt: creationDate
                        )

                        logger.info("📂 Created PDFFile object - URL: \(pdfFile.url.absoluteString), Filename: \(pdfFile.fileName)")
                        continuation.resume(returning: pdfFile)
                    } catch {
                        logger.error("❌ Failed to copy PDF file: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }

                if let coordinatorError = error {
                    logger.error("❌ NSFileCoordinator error: \(coordinatorError.localizedDescription)")
                    continuation.resume(throwing: coordinatorError)
                }
            }
        }
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
        NavigationStack {
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
                
                // 広告バナーを追加
                AdmobBannerView().frame(width: .infinity, height: 50)
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
        }
        .onAppear {
            viewStore.send(.loadPDFFiles)
        }
    }
}
