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
                if let document = PDFDocument(url: url) {
                    state.pdfDocument = document
                    state.currentPage = 0
                }
                return .none

            case .startReading:
                guard let page = state.pdfDocument?.page(at: state.currentPage),
                      let text = page.string else { return .none }

                state.isPlaying = true

                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                utterance.rate = 0.5
                utterance.pitchMultiplier = 1.0

                return .run { send in
                    await send(.clearHighlight)
                    await speechSynthesizer.speak(utterance)
                }

            case .stopReading:
                state.isPlaying = false
                return .run { send in
                    await speechSynthesizer.stopSpeaking()
                    await send(.clearHighlight)
                }

            case let .highlightWord(location, page):
                guard let text = page.string,
                      let selection = page.selection(for: NSRange(location: location, length: 1)) else { return .none }

                let bounds = selection.bounds(for: page)
                let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                highlight.color = .yellow.withAlphaComponent(0.5)
                page.addAnnotation(highlight)
                state.currentHighlight = highlight
                return .none

            case .clearHighlight:
                if let highlight = state.currentHighlight,
                   let page = highlight.page {
                    page.removeAnnotation(highlight)
                    state.currentHighlight = nil
                }
                return .none

            case let .speechWillSpeak(characterRange, _):
                guard let page = state.pdfDocument?.page(at: state.currentPage) else { return .none }
                return .send(.highlightWord(location: characterRange.location, page: page))

            case .speechDidFinish:
                state.isPlaying = false
                return .send(.clearHighlight)
            }
        }
    }
}

// MARK: - Dependencies

struct SpeechSynthesizerClient {
    var speak: (AVSpeechUtterance) async -> Void
    var stopSpeaking: () async -> Void
}

extension SpeechSynthesizerClient: DependencyKey {
    static let liveValue = Self(
        speak: { utterance in
            await withCheckedContinuation { continuation in
                let synthesizer = AVSpeechSynthesizer()
                synthesizer.speak(utterance)
                continuation.resume()
            }
        },
        stopSpeaking: {
            await withCheckedContinuation { continuation in
                let synthesizer = AVSpeechSynthesizer()
                synthesizer.stopSpeaking(at: .immediate)
                continuation.resume()
            }
        }
    )
}

extension DependencyValues {
    var speechSynthesizer: SpeechSynthesizerClient {
        get { self[SpeechSynthesizerClient.self] }
        set { self[SpeechSynthesizerClient.self] = newValue }
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
