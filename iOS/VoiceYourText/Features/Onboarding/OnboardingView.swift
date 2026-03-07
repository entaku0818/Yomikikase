import SwiftUI
import AVFoundation

// MARK: - Speech Helper

private final class OnboardingSpeaker: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var isSpeaking = false
    @Published var hasPlayed = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.hasPlayed = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentStep: Int
    @State private var demoText = "こんにちは！読み上げナレーターです。"
    @StateObject private var speaker = OnboardingSpeaker()

    init(onComplete: @escaping () -> Void, initialStep: Int = 0) {
        self.onComplete = onComplete
        self._currentStep = State(initialValue: initialStep)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ステップインジケーター
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: i == currentStep ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentStep)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 32)

                // コンテンツ
                Group {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: demoStep
                    default: featuresStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)

                Spacer()

                // ナビゲーションボタン
                navigationButtons
                    .padding(.bottom, 48)
                    .padding(.horizontal, 24)
            }
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

    // MARK: - Step 2: Interactive Demo

    private var demoStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("実際に試してみよう")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("テキストを編集して\n再生ボタンを押してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // テキスト入力エリア
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(height: 140)

                TextEditor(text: $demoText)
                    .font(.body)
                    .padding(12)
                    .frame(height: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(speaker.isSpeaking ? Color.blue : Color.clear, lineWidth: 2)
                    .animation(.easeInOut, value: speaker.isSpeaking)
            )
            .padding(.horizontal, 24)

            // 再生ボタン
            Button {
                if speaker.isSpeaking {
                    speaker.stop()
                } else {
                    speaker.speak(demoText)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                    Text(speaker.isSpeaking ? "停止" : "読み上げる")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(speaker.isSpeaking ? Color.red : Color.blue)
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }
            .animation(.easeInOut(duration: 0.2), value: speaker.isSpeaking)

            if speaker.hasPlayed {
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
            if currentStep == 0 {
                Button {
                    advance()
                } label: {
                    Text("はじめる")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
            } else if currentStep == 1 {
                Button {
                    speaker.stop()
                    advance()
                } label: {
                    Text(speaker.hasPlayed ? "次へ" : "スキップ")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(speaker.hasPlayed ? Color.blue : Color.gray)
                        .cornerRadius(16)
                }
            } else {
                Button {
                    UserDefaultsManager.shared.hasCompletedOnboarding = true
                    onComplete()
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

    // MARK: - Helpers

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }
}

#Preview("Step1 Welcome") {
    OnboardingView(onComplete: {}, initialStep: 0)
}

#Preview("Step2 Demo") {
    OnboardingView(onComplete: {}, initialStep: 1)
}

#Preview("Step3 Features") {
    OnboardingView(onComplete: {}, initialStep: 2)
}

#Preview("iPad Step1 Welcome", traits: .fixedLayout(width: 768, height: 1024)) {
    OnboardingView(onComplete: {}, initialStep: 0)
}

#Preview("iPad Step2 Demo", traits: .fixedLayout(width: 768, height: 1024)) {
    OnboardingView(onComplete: {}, initialStep: 1)
}

#Preview("iPad Step3 Features", traits: .fixedLayout(width: 768, height: 1024)) {
    OnboardingView(onComplete: {}, initialStep: 2)
}
