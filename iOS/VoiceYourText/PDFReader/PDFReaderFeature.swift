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
        var highlightedRange: NSRange? = nil
        var highlightedText: String? = nil  // ハイライトするテキスト
    }

    enum Action: Equatable {
        case loadPDF(URL)
        case startReading
        case stopReading
        case pdfLoaded(PDFDocument)
        case extractTextCompleted(String)
        case highlightRange(NSRange?)
        case speechFinished
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
                guard !state.pdfText.isEmpty else { return .none }
                state.isReading = true

                // ユーザー設定から音声設定を取得
                let language = UserDefaultsManager.shared.languageSetting ?? AVSpeechSynthesisVoice.currentLanguageCode()
                let rate = UserDefaultsManager.shared.speechRate
                let pitch = UserDefaultsManager.shared.speechPitch
                let volume: Float = 0.75

                let utterance = AVSpeechUtterance(string: state.pdfText)
                utterance.voice = AVSpeechSynthesisVoice(language: language)
                utterance.rate = rate
                utterance.pitchMultiplier = pitch
                utterance.volume = volume

                return .run { send in
                    // 音声セッションの設定
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                        try audioSession.setActive(true)
                    } catch {
                        logger.error("Failed to set audio session category: \(error)")
                    }
                    
                    try await speechSynthesizer.speakWithHighlight(
                        utterance,
                        { range, speechString in
                            // ハイライト更新
                            Task { @MainActor in
                                await send(.highlightRange(range))
                            }
                        },
                        {
                            // 読み上げ完了
                            Task { @MainActor in
                                await send(.speechFinished)
                            }
                        }
                    )
                }

            case .stopReading:
                state.isReading = false
                state.highlightedRange = nil
                state.highlightedText = nil
                return .run { _ in
                    await speechSynthesizer.stopSpeaking()
                }
                
            case .highlightRange(let range):
                state.highlightedRange = range
                
                // ハイライトするテキストを抽出
                if let range = range,
                   range.location + range.length <= state.pdfText.count {
                    
                    let nsString = state.pdfText as NSString
                    let substring = nsString.substring(with: range)
                    state.highlightedText = substring
                } else {
                    state.highlightedText = nil
                }
                return .none
                
            case .speechFinished:
                state.isReading = false
                state.highlightedRange = nil
                state.highlightedText = nil
                return .none
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
                PDFKitView(
                    document: pdfDocument,
                    highlightedText: viewStore.highlightedText
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(action: { viewStore.send(.startReading) }) {
                    Image(systemName: "play.fill")
                    Text("読み上げ開始")
                }
                .disabled(viewStore.isReading || viewStore.pdfText.isEmpty)

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
        .onDisappear {
            // 画面を離れる時に音声を停止
            if viewStore.isReading {
                viewStore.send(.stopReading)
            }
        }
    }
}

// PDFKitView.swift
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let highlightedText: String?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
        
        // 既存のハイライトをクリア
        pdfView.clearSelection()
        
        // 新しいハイライトを設定
        if let text = highlightedText, !text.isEmpty {
            // PDFで該当テキストを検索
            let selections = document.findString(text, withOptions: [])
            if let selection = selections.first {
                selection.color = UIColor.systemYellow
                pdfView.setCurrentSelection(selection, animate: true)
                
                // ハイライト部分にスクロール
                if let page = selection.pages.first {
                    pdfView.go(to: selection.bounds(for: page), on: page)
                }
            }
        }
    }
}
