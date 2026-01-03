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
        case syncPlayingState(Bool)  // ミニプレイヤーから戻ってきた時の同期用
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
                logger.info("Loading PDF from: \(url.absoluteString)")
                guard let document = PDFDocument(url: url) else {
                    logger.error("Failed to load PDF from: \(url.absoluteString)")
                    return .none
                }
                state.currentPDFURL = url
                logger.info("PDF loaded successfully: \(document.pageCount) pages")
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

            case .syncPlayingState(let isPlaying):
                // ミニプレイヤーから戻ってきた時の同期用
                state.isReading = isPlaying
                return .none
            }
        }
    }
}

// PDFReaderView.swift
struct PDFReaderView: View {
    @Environment(\.dismiss) private var dismiss
    let store: StoreOf<PDFReaderFeature>
    let parentStore: Store<Speeches.State, Speeches.Action>?
    @ObservedObject var viewStore: ViewStoreOf<PDFReaderFeature>
    @State private var showingSpeedPicker = false

    init(store: StoreOf<PDFReaderFeature>, parentStore: Store<Speeches.State, Speeches.Action>? = nil) {
        self.store = store
        self.parentStore = parentStore
        self.viewStore = ViewStore(self.store, observe: { $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
                    // 再生中でも止めずにdismiss（ミニプレイヤーで継続）
                    dismiss()
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .padding(.leading, 8)

                Spacer()
            }
            .frame(height: 56)
            .background(Color(UIColor.systemBackground))

            Divider()

            // PDF表示
            if let pdfDocument = viewStore.pdfDocument {
                PDFKitView(
                    document: pdfDocument,
                    highlightedText: viewStore.highlightedText
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                ProgressView("PDFを読み込み中...")
                Spacer()
            }

            // 広告バナー
            if !UserDefaultsManager.shared.isPremiumUser {
                AdmobBannerView()
                    .frame(height: 50)
            }

            // プレイヤーコントロール
            PlayerControlView(
                isSpeaking: viewStore.isReading,
                isTextEmpty: viewStore.pdfText.isEmpty,
                speechRate: UserDefaultsManager.shared.speechRate,
                onPlay: {
                    viewStore.send(.startReading)
                    // nowPlayingを更新（ミニプレイヤー用）
                    if let parentStore = parentStore, let url = viewStore.currentPDFURL {
                        let title = url.lastPathComponent
                        parentStore.send(.nowPlaying(.startPlaying(
                            title: title,
                            text: viewStore.pdfText,
                            source: .pdf(id: UUID(), url: url)
                        )))
                    }
                },
                onStop: {
                    viewStore.send(.stopReading)
                    parentStore?.send(.nowPlaying(.stopPlaying))
                },
                onSpeedTap: {
                    showingSpeedPicker = true
                }
            )
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if let url = viewStore.currentPDFURL {
                viewStore.send(.loadPDF(url))
            }
        }
        .onDisappear {
            // 再生中でも止めない（ミニプレイヤーで継続）
        }
        .onChange(of: viewStore.isReading) { _, isReading in
            // 読み上げ完了時（isReadingがfalseに変化した時）にnowPlayingを更新
            if !isReading {
                parentStore?.send(.nowPlaying(.stopPlaying))
            }
        }
        .confirmationDialog("再生速度", isPresented: $showingSpeedPicker, titleVisibility: .visible) {
            ForEach(SpeechSettings.speedOptions, id: \.self) { speed in
                Button(SpeechSettings.formatSpeedOption(speed)) {
                    UserDefaultsManager.shared.speechRate = speed
                }
            }
            Button("キャンセル", role: .cancel) {}
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
