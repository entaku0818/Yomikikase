import SwiftUI

// MARK: - B案 スクリーンショット設計
// 5枚構成 / テーマカラーグラデーション（ネイビー → パープル）
//
// Screen 01: ホーム  「読む手間を、声に任せよう」
// Screen 02: PDF    「PDF・Web・電子書籍に対応」
// Screen 03: ハイライト「リアルタイムハイライトで聴きやすい」
// Screen 04: マイファイル「保存して、いつでも続きから」
// Screen 05: バックグラウンド再生「画面を閉じても再生が続く」← PDM決定

#if DEBUG

// MARK: - B案 テーマカラー

private extension Color {
    /// グラデーション上部（深海ネイビー）
    static let bTop    = Color(red: 0.07, green: 0.07, blue: 0.22)
    /// グラデーション中間（ミッドナイトパープル）
    static let bMid    = Color(red: 0.20, green: 0.07, blue: 0.46)
    /// グラデーション下部（ヴァイオレット）
    static let bBottom = Color(red: 0.40, green: 0.16, blue: 0.68)
}

// MARK: - B案 グラデーション付きスクリーンショットラッパー

struct GradientScreenshotFrame<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.bTop, .bMid, .bBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Text(caption)
                    .font(.system(size: 44, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 36)
                    .padding(.top, 36)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                PhoneMockupView {
                    content()
                }
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 28)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Screen 05: ロック画面バックグラウンド再生

struct LockScreenPlayerContent: View {
    var body: some View {
        ZStack {
            // ロック画面背景：暗いグラデーション（フォン内なのでさらに深く）
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.20),
                    Color(red: 0.16, green: 0.04, blue: 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // ── 時刻 ──
                VStack(spacing: 3) {
                    Text("14:32")
                        .font(.system(size: 66, weight: .thin, design: .default))
                        .foregroundColor(.white)
                    Text("火曜日, 4月14日")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.top, 20)

                Spacer()

                // ── Now Playing カード（frosted glass） ──
                VStack(spacing: 0) {

                    // アートワーク行
                    HStack(spacing: 14) {
                        // アプリカラーのアートワーク
                        RoundedRectangle(cornerRadius: 9)
                            .fill(
                                LinearGradient(
                                    colors: [.bMid, .bBottom],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                            .overlay(
                                Image(systemName: "waveform")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("吾輩は猫である.pdf")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("Voice Narrator")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "heart")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    // プログレスバー
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.35))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(Color.primary)
                                    .frame(width: geo.size.width * 0.35, height: 3)
                                // 再生ヘッド
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 8, height: 8)
                                    .offset(x: geo.size.width * 0.35 - 4)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("2:14")
                            Spacer()
                            Text("-4:08")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                    // 再生コントロール
                    HStack {
                        Spacer()
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "pause.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "goforward.15")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 12)

                // ── ホームバーインジケーター ──
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 120, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - B案 Previews JA（5枚）

#Preview("📱B JA 01 Home", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "読む手間を、\n声に任せよう") {
        MockScreenWithTopTab(title: "読み上げ") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱B JA 02 PDF", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "PDF・Web・\n電子書籍に対応") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱B JA 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "リアルタイム\nハイライトで聴きやすい") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱B JA 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "保存して、\nいつでも続きから") {
        MockScreenWithTopTab(title: "マイファイル") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱B JA 05 Background", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "画面を閉じても\n再生が続く") {
        LockScreenPlayerContent()
    }
    .environment(\.locale, .init(identifier: "ja"))
}

// MARK: - B案 Previews EN（5枚）

#Preview("📱B EN 01 Home", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "Let Your Voice\nDo the Reading") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱B EN 02 PDF", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "PDF, Web &\neBooks Supported") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱B EN 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "Follow Along\nwith Highlights") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱B EN 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "Save &\nContinue Anytime") {
        MockScreenWithTopTab(title: "My Files") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱B EN 05 Background", traits: .fixedLayout(width: 430, height: 932)) {
    GradientScreenshotFrame(caption: "Plays On, Even With\nScreen Off") {
        LockScreenPlayerContent()
    }
    .environment(\.locale, .init(identifier: "en"))
}

// TODO: DE / ES / FR / IT / KO / TH / TR / VI は EN キャプションを差し替えて追加

#endif
