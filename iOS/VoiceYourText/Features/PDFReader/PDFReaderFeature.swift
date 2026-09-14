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
        @PresentationState var alert: AlertState<ReviewPromptAction>?
        var pdfText: String = ""
        var isReading: Bool = false
        var selectedPage: Int = 0
        var pdfDocument: PDFDocument?
        var currentPDFURL: URL?
        var highlightedRange: NSRange? = nil
        var highlightedText: String? = nil  // ハイライトするテキスト
        var startCharacterIndex: Int = 0
        var isFeedbackPresented: Bool = false
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
        case setStartCharacterIndex(Int)
        case pageTapped(page: Int, characterIndex: Int)
        case alert(PresentationAction<ReviewPromptAction>)
        case feedbackDismissed
    }

    /// 指定ページのテキストを抽出し、フッター文言除去・トリムまで行う。
    /// pdfLoaded(ページ0)とpageTapped(タップされたページ)の両方から共通で使う。
    private static func extractCleanedText(from document: PDFDocument, pageIndex: Int) -> String? {
        guard let page = document.page(at: pageIndex) else { return nil }
        let mainSelection = PDFSelection(document: document)
        let pageLength = page.numberOfCharacters
        if let pageContent = page.selection(for: NSRange(location: 0, length: pageLength)) {
            mainSelection.add(pageContent)
        }
        guard let extractedText = mainSelection.string else { return nil }
        return extractedText
            .replacingOccurrences(of: "Powered by TCPDF \\(www\\.tcpdf\\.org\\)\n*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.analytics) var analytics

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
                state.selectedPage = 0

                if let cleanedText = Self.extractCleanedText(from: document, pageIndex: 0) {
                    logger.log("extractedText \(cleanedText)")
                    return .send(.extractTextCompleted(cleanedText))
                }
                return .none

            case let .extractTextCompleted(text):
                state.pdfText = text
                return .none

            case .startReading:
                guard !state.isReading else { return .none }
                guard !state.pdfText.isEmpty else { return .none }

                let pdfText = state.pdfText
                let safeStart = min(state.startCharacterIndex, pdfText.count)
                let startStringIndex = pdfText.index(pdfText.startIndex, offsetBy: safeStart)
                let utteranceText = String(pdfText[startStringIndex...])

                state.isReading = true

                let language = userDefaults.languageSetting() ?? AVSpeechSynthesisVoice.currentLanguageCode()
                let rate = userDefaults.speechRate()
                let pitch = userDefaults.speechPitch()

                let utterance = AVSpeechUtterance(string: utteranceText)
                // 設定で選ばれた音声（Enhanced/Premium/パーソナルボイス）を優先して使う
                VoiceResolver.configure(utterance, languageCode: language, rate: rate, pitch: pitch)

                return .run { send in
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
                            // utterance は suffix なので safeStart 分オフセットして pdfText 上の位置に変換
                            let offsetRange = NSRange(location: range.location + safeStart, length: range.length)
                            Task { @MainActor in
                                await send(.highlightRange(offsetRange))
                            }
                        },
                        {
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
                // PDF読み上げもコア体験の一つとして、SpeechViewと同じ完了カウント・条件でレビュー事前確認を検討する
                let completedCount = UserDefaultsManager.shared.speechCompletedCount + 1
                UserDefaultsManager.shared.speechCompletedCount = completedCount
                analytics.logEvent("speech_completed", ["count": completedCount, "source": "pdf"])
                if let alert = ReviewRequestPrompt.alertForSpeechCompletion(completedCount: completedCount, analytics: analytics) {
                    state.alert = alert
                }
                return .none

            case .alert(.presented(.onGoodReview)):
                state.alert = ReviewRequestPrompt.markAnsweredPositively()
                return .none

            case .alert(.presented(.onBadReview)):
                state.alert = nil
                state.isFeedbackPresented = true
                return .none

            case .alert(.presented(.onAddReview)):
                ReviewRequestPrompt.requestSystemReview()
                return .none

            case .alert(.dismiss):
                return .none

            case .feedbackDismissed:
                state.isFeedbackPresented = false
                return .none

            case .syncPlayingState(let isPlaying):
                // ミニプレイヤーから戻ってきた時の同期用
                state.isReading = isPlaying
                return .none

            case let .setStartCharacterIndex(index):
                state.startCharacterIndex = index
                return .none

            case let .pageTapped(page, characterIndex):
                // タップされたページ単位でテキストを再抽出し、そのページ内でのcharacterIndexを
                // 正しい開始位置として使う（複数ページPDFで別ページをタップした際のズレを防ぐ）
                guard let document = state.pdfDocument,
                      let cleanedText = Self.extractCleanedText(from: document, pageIndex: page) else {
                    return .none
                }
                state.selectedPage = page
                state.pdfText = cleanedText
                state.startCharacterIndex = min(max(characterIndex, 0), cleanedText.count)
                return .none
            }
        }
        .ifLet(\.$alert, action: /Action.alert)
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
                    highlightedText: viewStore.highlightedText,
                    onTapCharacterIndex: { page, index in
                        viewStore.send(.pageTapped(page: page, characterIndex: index))
                    }
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
                },
                onTTSInfoTap: nil
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
        .sheet(
            isPresented: viewStore.binding(
                get: \.isFeedbackPresented,
                send: PDFReaderFeature.Action.feedbackDismissed
            )
        ) {
            FeedbackView()
        }
        .alert(store: self.store.scope(state: \.$alert, action: PDFReaderFeature.Action.alert))
    }
}

// PDFKitView.swift
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let highlightedText: String?
    var onTapCharacterIndex: ((_ page: Int, _ characterIndex: Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapCharacterIndex: onTapCharacterIndex)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tap)
        context.coordinator.pdfView = pdfView

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
        context.coordinator.onTapCharacterIndex = onTapCharacterIndex

        pdfView.clearSelection()

        if let text = highlightedText, !text.isEmpty {
            let selections = document.findString(text, withOptions: [])
            if let selection = selections.first {
                selection.color = UIColor.systemYellow
                pdfView.setCurrentSelection(selection, animate: true)
                if let page = selection.pages.first {
                    pdfView.go(to: selection.bounds(for: page), on: page)
                }
            }
        }
    }

    class Coordinator: NSObject {
        var onTapCharacterIndex: ((_ page: Int, _ characterIndex: Int) -> Void)?
        weak var pdfView: PDFView?

        init(onTapCharacterIndex: ((_ page: Int, _ characterIndex: Int) -> Void)?) {
            self.onTapCharacterIndex = onTapCharacterIndex
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView, let document = pdfView.document else { return }
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pageIndex = document.index(for: page)
            let pagePoint = pdfView.convert(location, to: page)
            let index = page.characterIndex(at: pagePoint)
            guard index != NSNotFound else { return }
            onTapCharacterIndex?(pageIndex, index)
        }
    }
}
