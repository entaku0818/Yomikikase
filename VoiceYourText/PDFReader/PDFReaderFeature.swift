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


@Reducer
struct PDFReaderFeature {
    @ObservableState
    struct State: Equatable {
        var currentPage: Int = 0
        var isPlaying: Bool = false
        var pdfDocument: PDFDocument?
        var currentHighlight: PDFAnnotation?
    }

    enum Action {
        case loadPDF(URL)
        case startReading
        case stopReading
        case highlightWord(location: Int, page: PDFPage)
        case clearHighlight
        case speechWillSpeak(characterRange: NSRange, utterance: AVSpeechUtterance)
        case speechDidFinish
    }

    @Dependency(\.speechSynthesizer) var speechSynthesizer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loadPDF(url):
                logger.info("Loading PDF from URL: \(url.absoluteString)")
                if let document = PDFDocument(url: url) {
                    logger.info("Successfully loaded PDF document with \(document.pageCount) pages")
                    state.pdfDocument = document
                    state.currentPage = 0
                } else {
                    logger.error("Failed to load PDF document from \(url.absoluteString)")
                }
                return .none

            case .startReading:
                logger.info("Starting reading process")
                guard let page = state.pdfDocument?.page(at: state.currentPage) else {
                    return .none
                }
                guard let text = page.string else {
                    return .none
                }

                logger.debug("Extracted text length: \(text.count) characters")
                state.isPlaying = true

                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                utterance.rate = 0.5
                utterance.pitchMultiplier = 1.0

                return .run { [utterance] send in
                    logger.info("Initializing speech synthesis")
                    await send(.clearHighlight)
                    do {
                        try await speechSynthesizer.speak(utterance)
                        logger.info("Speech synthesis started successfully")
                    } catch {
                        logger.error("Speech synthesis failed: \(error.localizedDescription)")
                    }
                }

            case .stopReading:
                logger.info("Stopping reading process")
                state.isPlaying = false
                return .run { _ in
                    await speechSynthesizer.stopSpeaking()
                    logger.info("Reading stopped successfully")
                }

            case let .highlightWord(location, page):
                logger.debug("Attempting to highlight word at location: \(location)")
                guard let selection = page.selection(for: NSRange(location: location, length: 1)) else {
                    logger.error("Failed to create selection at location \(location)")
                    return .none
                }

                let bounds = selection.bounds(for: page)
                logger.debug("Created highlight bounds: \(bounds.debugDescription)")

                let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                highlight.color = .yellow.withAlphaComponent(0.5)
                page.addAnnotation(highlight)
                state.currentHighlight = highlight
                return .none

            case .clearHighlight:
                logger.debug("Clearing current highlight")
                if let highlight = state.currentHighlight,
                   let page = highlight.page {
                    page.removeAnnotation(highlight)
                    state.currentHighlight = nil
                    logger.debug("Highlight cleared successfully")
                }
                return .none

            case let .speechWillSpeak(characterRange, _):
                logger.debug("Speech will speak range: \(characterRange.location) to \(NSMaxRange(characterRange))")
                guard let page = state.pdfDocument?.page(at: state.currentPage) else {
                    logger.error("Failed to find page for highlighting")
                    return .none
                }
                return .send(.highlightWord(location: characterRange.location, page: page))

            case .speechDidFinish:
                logger.info("Speech synthesis completed")
                state.isPlaying = false
                return .send(.clearHighlight)
            }
        }
    }
}


// MARK: - Views

struct PDFReaderView: View {
    let store: StoreOf<PDFReaderFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                PDFKitView(document: viewStore.pdfDocument)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Button {
                        if viewStore.isPlaying {
                            store.send(.stopReading)
                        } else {
                            store.send(.startReading)
                        }
                    } label: {
                        Image(systemName: viewStore.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title)
                            .padding()
                    }
                }
                .padding()
            }
            .onAppear {
                if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
                    store.send(.loadPDF(url))
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
