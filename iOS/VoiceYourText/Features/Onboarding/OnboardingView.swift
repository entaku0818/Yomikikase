import SwiftUI
import AVFoundation
import PDFKit
import ComposableArchitecture

// MARK: - Sample PDF

func makeSamplePDFData() -> Data {
    let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
    return renderer.pdfData { ctx in
        ctx.beginPage()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 26),
            .foregroundColor: UIColor.black
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.darkGray
        ]
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: UIColor(white: 0.5, alpha: 1)
        ]
        "読み上げナレーターの使い方".draw(at: CGPoint(x: 48, y: 60), withAttributes: titleAttrs)
        UIColor(white: 0.85, alpha: 1).setFill()
        UIRectFill(CGRect(x: 48, y: 100, width: 499, height: 1))
        let body = "このアプリは、PDFや電子書籍、ウェブページを\n音声で読み上げます。\n\n使い方はとても簡単です。\nファイルを開いて、再生ボタンを押すだけ。\n\n通勤中、料理中、運動中など\nながら聴きに最適です。"
        (body as NSString).draw(
            in: CGRect(x: 48, y: 120, width: 499, height: 400),
            withAttributes: bodyAttrs
        )
        let footer = "読み上げナレーター  |  ver 1.0"
        (footer as NSString).draw(at: CGPoint(x: 48, y: 800), withAttributes: lineAttrs)
    }
}

private let sampleReadText = "読み上げナレーターの使い方。このアプリは、PDFや電子書籍、ウェブページを音声で読み上げます。使い方はとても簡単です。ファイルを開いて、再生ボタンを押すだけ。通勤中、料理中、運動中など、ながら聴きに最適です。"

// MARK: - PDF UIViewRepresentable

private struct SamplePDFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFKit.PDFView {
        let view = PDFKit.PDFView()
        view.displayMode = .singlePage
        view.autoScales = true
        view.backgroundColor = .white
        view.isUserInteractionEnabled = false
        if let doc = PDFDocument(data: data) {
            view.document = doc
        }
        return view
    }

    func updateUIView(_ uiView: PDFKit.PDFView, context: Context) {
        guard uiView.document == nil, !data.isEmpty,
              let doc = PDFDocument(data: data) else { return }
        uiView.document = doc
    }
}

// MARK: - Speech Helper

private final class OnboardingSpeaker: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    var speakStartTime: Date?
    var onCompleted: ((Double) -> Void)?
    var onCancelled: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        speakStartTime = Date()
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            let duration = self.speakStartTime.map { Date().timeIntervalSince($0) } ?? 0
            self.onCompleted?(duration)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.onCancelled?()
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingReducer>
    @StateObject private var speaker = OnboardingSpeaker()

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == store.currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: i == store.currentStep ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: store.currentStep)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 32)

                Group {
                    switch store.currentStep {
                    case 0: welcomeStep
                    case 1: demoStep
                    default: featuresStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(store.currentStep)
                .onAppear {
                    store.send(.view(.stepViewAppeared(store.currentStep)))
                }

                Spacer()

                navigationButtons
                    .padding(.bottom, 48)
                    .padding(.horizontal, 24)
            }
        }
        .onAppear {
            speaker.onCompleted = { duration in
                store.send(.speechCompleted(duration))
            }
            speaker.onCancelled = {
                store.send(.speechCancelled)
            }
        }
        .task {
            // PDF generation is CPU-bound; offload to avoid blocking the main thread
            let data = await Task.detached(priority: .utility) {
                makeSamplePDFData()
            }.value
            store.send(.samplePDFGenerated(data))
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 8)

            VStack(spacing: 16) {
                Text("読み上げナレーター")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("テキスト・PDF・ウェブ・電子書籍を\n声に出して読んでくれるアプリです")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                HStack(spacing: 8) {
                    ForEach(["勉強", "読書", "仕事の資料"], id: \.self) { tag in
                        Text(tag)
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 2: PDF Demo

    private var demoStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("PDFをそのまま読み上げ")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("サンプルPDFで試してみよう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    Group {
                        if let data = store.samplePDFData {
                            SamplePDFView(data: data)
                        } else {
                            ProgressView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            store.isSpeaking ? Color.blue : Color.gray.opacity(0.25),
                            lineWidth: store.isSpeaking ? 2 : 1
                        )
                        .animation(.easeInOut, value: store.isSpeaking)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                .frame(height: 210)
                .padding(.horizontal, 24)

            Button {
                if store.isSpeaking {
                    speaker.stop()
                    store.send(.view(.demoStopTapped))
                } else {
                    store.send(.view(.demoPlayTapped))
                    speaker.speak(sampleReadText)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: store.isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                    Text(store.isSpeaking ? "停止" : "▶ 読み上げる")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(store.isSpeaking ? Color.red : Color.blue)
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }
            .animation(.easeInOut(duration: 0.2), value: store.isSpeaking)

            if store.hasPlayed {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("体験完了！次へ進めます")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    // MARK: - Step 3: Features

    private var featuresStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("様々なコンテンツに対応")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("こんな使い方ができます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                featureRow(icon: "doc.richtext.fill", color: .red,
                           title: "PDF・書類", description: "PDFやスキャン書類を読み上げ")
                featureRow(icon: "link", color: .teal,
                           title: "ウェブページ", description: "URLを貼るだけで本文を読み上げ")
                featureRow(icon: "books.vertical.fill", color: .brown,
                           title: "電子書籍", description: "EPUBファイルをそのまま読み上げ")
                featureRow(icon: "externaldrive.fill", color: .green,
                           title: "Googleドライブ", description: "クラウドのファイルに直接アクセス")
            }
            .padding(.horizontal, 24)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            if store.currentStep == 0 {
                Button {
                    store.send(.view(.nextTapped), animation: .easeInOut(duration: 0.3))
                } label: {
                    Text("はじめる")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
            } else if store.currentStep == 1 {
                Button {
                    speaker.stop()
                    if store.hasPlayed {
                        store.send(.view(.nextTapped), animation: .easeInOut(duration: 0.3))
                    } else {
                        store.send(.view(.skipTapped), animation: .easeInOut(duration: 0.3))
                    }
                } label: {
                    Text(store.hasPlayed ? "次へ" : "スキップ")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(store.hasPlayed ? Color.blue : Color.gray)
                        .cornerRadius(16)
                }
            } else {
                Button {
                    store.send(.view(.completeTapped))
                } label: {
                    Text("使い始める")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Step1 Welcome") {
    OnboardingView(store: Store(initialState: OnboardingReducer.State(currentStep: 0)) {
        OnboardingReducer(onComplete: {})
    })
}

#Preview("Step2 PDF Demo") {
    OnboardingView(store: Store(initialState: OnboardingReducer.State(currentStep: 1)) {
        OnboardingReducer(onComplete: {})
    })
}

#Preview("Step3 Features") {
    OnboardingView(store: Store(initialState: OnboardingReducer.State(currentStep: 2)) {
        OnboardingReducer(onComplete: {})
    })
}

#Preview("iPad Step1 Welcome", traits: .fixedLayout(width: 768, height: 1024)) {
    OnboardingView(store: Store(initialState: OnboardingReducer.State(currentStep: 0)) {
        OnboardingReducer(onComplete: {})
    })
}

#Preview("iPad Step2 PDF Demo", traits: .fixedLayout(width: 768, height: 1024)) {
    OnboardingView(store: Store(initialState: OnboardingReducer.State(currentStep: 1)) {
        OnboardingReducer(onComplete: {})
    })
}

#Preview("iPad Step3 Features", traits: .fixedLayout(width: 768, height: 1024)) {
    OnboardingView(store: Store(initialState: OnboardingReducer.State(currentStep: 2)) {
        OnboardingReducer(onComplete: {})
    })
}
