//
//  File.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2025/01/17.
//

import Foundation
import ComposableArchitecture
import PDFKit
import AVFoundation
import SwiftUI
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.app.pdfreader",
    category: "PDFReader"
)



struct PDFReaderFeature: Reducer {
    struct State: Equatable {
        var pdfText: String = ""
        var isReading: Bool = false
        var selectedPage: Int = 0
        var pdfDocument: PDFDocument?
        var currentPDFURL: URL?
    }

    enum Action: Equatable {
        case loadPDF(URL)
        case startReading
        case stopReading
        case pdfLoaded(PDFDocument)
        case extractTextCompleted(String)
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .loadPDF(url):
                guard let document = PDFDocument(url: url) else {
                    return .none
                }
                state.currentPDFURL = url
                return .send(.pdfLoaded(document))

            case let .pdfLoaded(document):
                state.pdfDocument = document

                // PDFSelectionを初期化
                let mainSelection = PDFSelection(document: document)

                // ページ全体を選択する（より確実な方法）
                if let page = document.page(at: 0) {
                    let pageLength = page.numberOfCharacters
                    // ページの先頭から最後までを選択
                    if let pageContent = page.selection(for: NSRange(location: 0, length: pageLength)) {
                        mainSelection.add(pageContent)
                    }
                }

                // 抽出したテキストを整形
                if let extractedText = mainSelection.string {
                    logger.log("extractedText \(extractedText)")
                    // 不要な文字列を除去
                    let cleanedText = extractedText
                        .replacingOccurrences(of: "Powered by TCPDF \\(www\\.tcpdf\\.org\\)\n*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    return .send(.extractTextCompleted(cleanedText))
                }
                return .none

            case let .extractTextCompleted(text):
                state.pdfText = text
                return .none

            case .startReading:
                guard !state.isReading else { return .none }
                state.isReading = true

                let utterance = AVSpeechUtterance(string: state.pdfText)
                utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                utterance.rate = 0.5
                utterance.pitchMultiplier = 1.0

                return .run { send in
                    try await speechSynthesizer.speak(utterance)
                    await send(.stopReading)
                }

            case .stopReading:
                state.isReading = false
                return .run { _ in
                    await speechSynthesizer.stopSpeaking()
                }
            }
        }
    }
}

// PDFReaderView.swift
struct PDFReaderView: View {
    let store: StoreOf<PDFReaderFeature>
    @ObservedObject var viewStore: ViewStoreOf<PDFReaderFeature>

    init(store: StoreOf<PDFReaderFeature>) {
        self.store = store
        self.viewStore = ViewStore(self.store, observe: { $0 })
    }

    var body: some View {
        VStack {
            if let pdfDocument = viewStore.pdfDocument {
                PDFKitView(document: pdfDocument)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(action: { viewStore.send(.startReading) }) {
                    Image(systemName: "play.fill")
                    Text("読み上げ開始")
                }
                .disabled(viewStore.isReading)

                Button(action: { viewStore.send(.stopReading) }) {
                    Image(systemName: "stop.fill")
                    Text("停止")
                }
                .disabled(!viewStore.isReading)
            }
            .padding()
        }
        .onAppear {
            if let url = viewStore.currentPDFURL {
                viewStore.send(.loadPDF(url))
            }
        }
    }
}

// PDFKitView.swift
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
    }
}
