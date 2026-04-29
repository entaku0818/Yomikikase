import SwiftUI

#if DEBUG
struct ScreenshotView: View {
    @State private var currentScreen = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            switch currentScreen {
            case 0:
                MockScreenWithTopTab(title: "読み上げ") {
                    HomeContent()
                }
            case 1:
                HighlightReadingContent()
            case 2:
                MockScreenWithTopTab(title: "設定") {
                    SettingsContent()
                }
            case 3:
                PDFReadingContent()
            default:
                MockScreenWithTopTab(title: "読み上げ") {
                    HomeContent()
                }
            }
        }
        .onTapGesture {
            if currentScreen < 3 {
                currentScreen += 1
            } else {
                dismiss()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - App Store スクリーンショットラッパー

struct AppStoreScreenshot<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Text(caption)
                .font(.system(size: 38, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 28)
                .padding(.top, 56)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
                .background(Color.white)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - 共通レイアウト（上タブ付き）
struct MockScreenWithTopTab<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー（大タイトルスタイル）
            HStack {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(.systemBackground))

            content
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - ホーム画面コンテンツ
struct HomeContent: View {
    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                GridItemView(icon: "doc.text.fill", title: "テキスト", color: .blue, isEnabled: true)
                GridItemView(icon: "doc.richtext.fill", title: "PDF", color: .red, isEnabled: true)
                GridItemView(icon: "doc.plaintext.fill", title: "TXTファイル", color: .orange, isEnabled: true)
                GridItemView(icon: "externaldrive.fill", title: "Gドライブ", color: .green, isEnabled: true)
                GridItemView(icon: "books.vertical.fill", title: "本", color: .brown, isEnabled: true)
                GridItemView(icon: "camera.fill", title: "スキャン", color: .indigo, isEnabled: true)
                GridItemView(icon: "link", title: "リンク", color: .teal, isEnabled: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct GridItemView: View {
    let icon: String
    let title: String
    let color: Color
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(isEnabled ? color : Color.gray.opacity(0.5))
                .frame(width: 50, height: 50)
                .background((isEnabled ? color : Color.gray).opacity(0.1))
                .cornerRadius(12)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(isEnabled ? Color(.systemBackground) : Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(isEnabled ? 0.05 : 0.02), radius: isEnabled ? 4 : 2, x: 0, y: isEnabled ? 2 : 1)
    }
}

// MARK: - ハイライト読み上げ画面コンテンツ
struct HighlightReadingContent: View {
    // 読み上げ中の段落：ハイライト単語 + Boldフォント
    var activeText: AttributedString {
        var text = AttributedString("どこで生れたかとんと見当がつかぬ。何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。")
        if let range = text.range(of: "じめじめした") {
            text[range].backgroundColor = Color.orange
            text[range].foregroundColor = Color.white
            text[range].font = Font.system(size: 19, weight: .bold)
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー：アイコン + タイトル + 音声波形インジケーター
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Voice Narrator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Spacer()
                // 再生中アニメーション風バー（静止版）
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach([8, 14, 10, 18, 12], id: \.self) { h in
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: 3, height: CGFloat(h))
                    }
                }
                .padding(.trailing, 16)
            }
            .background(Color(.systemBackground))

            VStack(spacing: 0) {
                // テキストエリア：3段階表示（済み / 現在 / 次）
                VStack(alignment: .leading, spacing: 14) {
                    // 読み上げ済み（薄め）
                    Text("国境の長いトンネルを抜けると雪国であった。夜の底が白くなった。")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .lineSpacing(5)

                    // 現在読み上げ中（左縦線 + 薄オレンジ背景 + ハイライト単語）
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 3)
                            .cornerRadius(1.5)
                        Text(activeText)
                            .font(.system(size: 19))
                            .lineSpacing(7)
                            .padding(.leading, 10)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)

                    // 次の段落（より薄め）
                    Text("吾輩はここで始めて人間というものを見た。しかもあとで聞くとそれは書生という人間中で一番獰悪な種族であったそうだ。")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryLabel))
                        .lineSpacing(5)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // プレイヤーコントロール
                VStack(spacing: 0) {
                    // プログレスバー
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: geo.size.width * 0.38, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    HStack(spacing: 40) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(.primary)
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 62))
                            .foregroundColor(.orange)
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 14)

                    Text("x1.0")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                }
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
            }
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - マイファイル画面コンテンツ（HomeViewの最近のファイルセクションに合わせる）
struct MyFilesContent: View {
    struct FileItem {
        let title: String
        let date: String
        let fileType: String
    }

    let files = [
        FileItem(title: "マーケティング戦略2025.pdf", date: "今日", fileType: "pdf"),
        FileItem(title: "会議メモ_4月", date: "今日", fileType: "txt"),
        FileItem(title: "英語学習テキスト_Unit3", date: "昨日", fileType: "txt"),
        FileItem(title: "プロジェクト計画書.txt", date: "昨日", fileType: "txt"),
        FileItem(title: "読書記録_春", date: "2日前", fileType: "txt"),
        FileItem(title: "技術書_Swift入門", date: "3日前", fileType: "epub"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // セクションヘッダー
            HStack {
                Text("最近のファイル")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // ファイル一覧（VStack - ImageRenderer対応）
            VStack(spacing: 8) {
                ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                    let iconName = file.fileType == "epub" ? "books.vertical.fill" : "doc.text.fill"
                    let iconColor: Color = file.fileType == "epub" ? .brown : .blue

                    HStack {
                        Image(systemName: iconName)
                            .font(.system(size: 20))
                            .foregroundColor(iconColor)
                            .frame(width: 32, height: 32)
                            .background(iconColor.opacity(0.1))
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.title)
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(1)
                            Text(file.date)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "play.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 設定画面コンテンツ
struct SettingsContent: View {
    var body: some View {
        // ScrollViewはImageRendererで空白になるのでVStackで直接表示
        VStack(alignment: .leading, spacing: 20) {
            Text("音声設定")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    VStack(spacing: 0) {
                        HStack {
                            Text("音声の選択")
                            Spacer()
                            Text("Eddy")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(.systemBackground))

                        Divider().padding(.leading)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("声の速さ")
                                Spacer()
                                Text("x1.0（標準）")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            HStack {
                                Image(systemName: "tortoise.fill")
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(0.5))
                                    .tint(.blue)
                                Image(systemName: "hare.fill")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("遅い").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("標準 1.0").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("速い").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))

                        Divider().padding(.leading)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("声の高さ")
                                Spacer()
                                Text("x1.0（標準）")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                            HStack {
                                Image(systemName: "speaker.wave.1.fill")
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(0.33))
                                    .tint(.blue)
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("低い").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("標準 1.0").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("高い").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Text("辞書")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    HStack {
                        Image(systemName: "character.book.closed.fill")
                        Text("ユーザー辞書")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Text("言語設定")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    HStack {
                        Text("言語選択")
                        Spacer()
                        Text("Japanese")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Text("読み上げ設定をデフォルト値に戻す")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - PDF読み上げ画面コンテンツ
struct PDFReadingContent: View {
    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー（PhoneMockupViewのtopReservedがあるのでpadding(.top, 44)不要）
            HStack {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                Spacer()
                Text("吾輩は猫である.pdf")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))

            // PDFテキスト表示エリア（ScrollViewはImageRendererで空白になるのでVStackで直接表示）
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Text("吾輩は猫である。名前は")
                    Text("まだ無い")
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .background(Color.orange)
                    Text("。")
                }
                .font(.body)
                Text("どこで生れたかとんと見当がつかぬ。何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。")
                    .font(.body)
                Text("吾輩はここで始めて人間というものを見た。しかもあとで聞くとそれは書生という人間中で一番獰悪な種族であったそうだ。")
                    .font(.body)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.systemBackground))

            Spacer()

            // 再生コントロール
            VStack(spacing: 16) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: geo.size.width * 0.15, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                .padding(.horizontal)

                HStack(spacing: 40) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(.primary)
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                    Image(systemName: "goforward.15")
                        .font(.title)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - ユーザー辞書画面コンテンツ
struct UserDictionaryContent: View {
    let entries = [
        ("薔薇", "ばら"),
        ("麒麟", "きりん"),
        ("Claude", "クロード"),
        ("土御門", "つちみかど"),
        ("読売新聞", "よみうりしんぶん"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            HStack {
                Spacer()
                Text("ユーザー辞書")
                    .font(.headline)
                Spacer()
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .padding(.top, 44)
            .background(Color(.systemBackground))

            // 説明テキスト
            HStack {
                Text("単語の読み方をカスタマイズできます")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            // 辞書エントリ一覧
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.0)
                                        .font(.headline)
                                    Text(entry.1)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))

                            if index < entries.count - 1 {
                                Divider().padding(.leading)
                            }
                        }
                    }
                }
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ScreenshotView()
}

// MARK: - JA App Store Previews

#Preview("JA 01 Welcome") {
    AppStoreScreenshot(caption: "読み上げナレーター\nへようこそ") {
        OnboardingView(onComplete: {}, initialStep: 0)
    }
}

#Preview("JA 02 Demo") {
    AppStoreScreenshot(caption: "体験して\nみよう") {
        OnboardingView(onComplete: {}, initialStep: 1)
    }
}

#Preview("JA 03 Features") {
    AppStoreScreenshot(caption: "PDF・ウェブ\n電子書籍も対応") {
        OnboardingView(onComplete: {}, initialStep: 2)
    }
}

#Preview("JA 04 Highlight") {
    AppStoreScreenshot(caption: "ハイライトで\n読み上げ") {
        HighlightReadingContent()
    }
}

// MARK: - EN App Store Previews

#Preview("EN 01 Welcome") {
    AppStoreScreenshot(caption: "Welcome to\nVoice Narrator") {
        OnboardingView(onComplete: {}, initialStep: 0)
    }
}

#Preview("EN 02 Demo") {
    AppStoreScreenshot(caption: "Try it\nyourself") {
        OnboardingView(onComplete: {}, initialStep: 1)
    }
}

#Preview("EN 03 Features") {
    AppStoreScreenshot(caption: "PDF, Web &\neBooks supported") {
        OnboardingView(onComplete: {}, initialStep: 2)
    }
}

#Preview("EN 04 Highlight") {
    AppStoreScreenshot(caption: "Follow along\nwith highlights") {
        HighlightReadingContent()
    }
}

// MARK: - iPad Raw Previews

#Preview("iPad Highlight", traits: .fixedLayout(width: 768, height: 1024)) {
    HighlightReadingContent()
}

// MARK: - Raw Previews (no caption)

#Preview("iPhone MyFiles") {
    MockScreenWithTopTab(title: "マイファイル") {
        MyFilesContent()
    }
}

#Preview("iPad MyFiles", traits: .fixedLayout(width: 768, height: 1024)) {
    MockScreenWithTopTab(title: "マイファイル") {
        MyFilesContent()
    }
}

// MARK: - Phone Mockup Frame

struct PhoneMockupView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let outerCR = w * 0.125
            let bezel: CGFloat = 8
            let innerCR = outerCR - bezel
            let diWidth = w * 0.30
            let diHeight: CGFloat = max(h * 0.030, 22)   // 実機に近い縦幅
            let diTopPad: CGFloat = max(h * 0.018, 12)   // 上余白を広めに
            let topReserved = bezel + diTopPad + diHeight + 4

            ZStack(alignment: .top) {
                // Phone body
                RoundedRectangle(cornerRadius: outerCR)
                    .fill(Color.black)

                // Screen area background
                RoundedRectangle(cornerRadius: innerCR)
                    .fill(Color(.systemBackground))
                    .padding(bezel)

                // Content pushed below Dynamic Island
                VStack(spacing: 0) {
                    Color.clear.frame(height: topReserved)
                    content()
                }
                .clipShape(RoundedRectangle(cornerRadius: innerCR))
                .padding(bezel)

                // Dynamic Island
                Capsule()
                    .fill(Color.black)
                    .frame(width: diWidth, height: diHeight)
                    .padding(.top, diTopPad + bezel)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - App Store Screenshot with Phone Frame

struct AppStoreScreenshotWithFrame<Content: View>: View {
    let caption: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(caption)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 36)
            .padding(.bottom, 20)

            Spacer(minLength: 0)

            PhoneMockupView {
                content()
            }
            .aspectRatio(9.0 / 19.5, contentMode: .fit)
            .padding(.horizontal, 28)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Framed App Store Previews (caption + phone frame, ready for fastlane)
// iPhone 6.7" frame: 430 × 932 pt

// ── JA ──
#Preview("📱 JA 01 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(
        caption: "移動中に\nPDFを読み上げ",
        subtitle: "通勤・運動・料理中にPDFや長文を自動読み上げ。\n耳でインプット、毎日のながら時間を活用。"
    ) {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱 JA 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF・Web・\n電子書籍に対応") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱 JA 03 Sources", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "7つのソースから\nかんたんインポート") {
        MockScreenWithTopTab(title: "読み上げ") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "ja"))
}

#Preview("📱 JA 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "保存して、\nいつでも続きから") {
        MockScreenWithTopTab(title: "マイファイル") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "ja"))
}

// ── EN ──
#Preview("📱 EN 01 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(
        caption: "Listen While\nYou Move",
        subtitle: "Auto-read PDFs, ebooks & web pages hands-free.\nTurn your commute into learning time."
    ) {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱 EN 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF, Web &\neBooks Supported") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱 EN 03 Sources", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "7 Sources,\nOne App") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("📱 EN 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Save &\nContinue Anytime") {
        MockScreenWithTopTab(title: "My Files") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "en"))
}

// ── DE ──
#Preview("📱 DE 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Lesen leicht\ngemacht") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "de"))
}

#Preview("📱 DE 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF, Web und\neBooks unterstützt") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "de"))
}

#Preview("📱 DE 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Echtzeit-\nHervorhebung") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "de"))
}

#Preview("📱 DE 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Speichern &\nJederzeit weiterlesen") {
        MockScreenWithTopTab(title: "Meine Dateien") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "de"))
}

// ── ES ──
#Preview("📱 ES 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Deja que la voz\nlea por ti") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "es"))
}

#Preview("📱 ES 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF, web\ny eBooks") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "es"))
}

#Preview("📱 ES 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Subrayado\nen tiempo real") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "es"))
}

#Preview("📱 ES 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Guarda y\ncontinúa siempre") {
        MockScreenWithTopTab(title: "Mis archivos") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "es"))
}

// ── FR ──
#Preview("📱 FR 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Laissez la voix\nfaire la lecture") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "fr"))
}

#Preview("📱 FR 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF, Web et\ne-books pris en charge") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "fr"))
}

#Preview("📱 FR 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Surlignage\nen temps réel") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "fr"))
}

#Preview("📱 FR 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Enregistrez &\nreprenez à tout moment") {
        MockScreenWithTopTab(title: "Mes fichiers") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "fr"))
}

// ── IT ──
#Preview("📱 IT 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Lascia che la voce\nlegga per te") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "it"))
}

#Preview("📱 IT 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF, Web ed\ne-book supportati") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "it"))
}

#Preview("📱 IT 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Evidenziazione\nin tempo reale") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "it"))
}

#Preview("📱 IT 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Salva e\ncontinua sempre") {
        MockScreenWithTopTab(title: "I miei file") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "it"))
}

// ── KO ──
#Preview("📱 KO 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "읽는 수고를\n목소리에 맡겨요") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "ko"))
}

#Preview("📱 KO 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF・웹・\n전자책 지원") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "ko"))
}

#Preview("📱 KO 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "실시간 하이라이트로\n듣기 편해요") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "ko"))
}

#Preview("📱 KO 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "저장하고\n언제든지 이어서") {
        MockScreenWithTopTab(title: "내 파일") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "ko"))
}

// ── TH ──
#Preview("📱 TH 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "ปล่อยให้เสียง\nอ่านแทนคุณ") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "th"))
}

#Preview("📱 TH 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "รองรับ PDF\nเว็บ และ eBook") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "th"))
}

#Preview("📱 TH 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "ไฮไลต์\nแบบเรียลไทม์") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "th"))
}

#Preview("📱 TH 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "บันทึกแล้ว\nต่อได้ทุกเมื่อ") {
        MockScreenWithTopTab(title: "ไฟล์ของฉัน") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "th"))
}

// ── TR ──
#Preview("📱 TR 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Okuma zahmetini\nsese bırakın") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "tr"))
}

#Preview("📱 TR 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "PDF, Web ve\ne-Kitap desteği") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "tr"))
}

#Preview("📱 TR 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Gerçek zamanlı\nvurgu") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "tr"))
}

#Preview("📱 TR 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Kaydet &\nistediğinde devam et") {
        MockScreenWithTopTab(title: "Dosyalarım") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "tr"))
}

// ── VI ──
#Preview("📱 VI 01 Demo", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Để giọng nói\nđọc cho bạn") {
        MockScreenWithTopTab(title: "Voice Narrator") { HomeContent() }
    }
    .environment(\.locale, .init(identifier: "vi"))
}

#Preview("📱 VI 02 Features", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Hỗ trợ PDF\nWeb & eBook") {
        PDFReadingContent()
    }
    .environment(\.locale, .init(identifier: "vi"))
}

#Preview("📱 VI 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Tô sáng\ntheo thời gian thực") {
        HighlightReadingContent()
    }
    .environment(\.locale, .init(identifier: "vi"))
}

#Preview("📱 VI 04 MyFiles", traits: .fixedLayout(width: 430, height: 932)) {
    AppStoreScreenshotWithFrame(caption: "Lưu lại &\ntiếp tục bất cứ lúc nào") {
        MockScreenWithTopTab(title: "Tệp của tôi") { MyFilesContent() }
    }
    .environment(\.locale, .init(identifier: "vi"))
}
#endif
