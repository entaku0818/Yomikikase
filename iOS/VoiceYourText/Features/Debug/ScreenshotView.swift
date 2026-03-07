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
            // 上部ナビゲーションバー（モック）
            HStack {
                Spacer()
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .padding(.top, 44)
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
                .foregroundColor(isEnabled ? color : .gray)
            Text(title)
                .font(.subheadline)
                .foregroundColor(isEnabled ? .primary : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - ハイライト読み上げ画面コンテンツ（実際のSpeechViewに近いモック）
struct HighlightReadingContent: View {
    let speeches = [
        "国境の長いトンネルを抜けると雪国であった。",
        "吾輩は猫である。名前はまだない。",
        "親譲の無鉄砲で小供の時から損ばかりしてい",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            HStack {
                Spacer()
                Text("Voice Narrator")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .padding(.top, 44)
            .background(Color(.systemBackground))

            VStack(spacing: 0) {
                // ハイライト付きテキスト入力エリア
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                    HStack(spacing: 0) {
                        Text("国境の長い")
                            .font(.system(size: 16))
                        Text("トンネル")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 2)
                            .background(Color.orange)
                        Text("を抜けると雪国であった。夜の底が白くなった。信号所に汽車が止まった。")
                            .font(.system(size: 16))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .padding()

                // スピーチリスト
                List {
                    ForEach(speeches, id: \.self) { speech in
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            Text(speech)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)

                // プレイヤーコントロール
                VStack(spacing: 8) {
                    HStack(spacing: 24) {
                        Text("x1.0")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 44)
                        Spacer()
                        Button {} label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 52))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 44)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
            }
            .background(Color(.systemGroupedBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - マイファイル画面コンテンツ
struct MyFilesContent: View {
    let files = [
        ("国境の長いトンネルを抜けると雪国であった", "今日", "txt"),
        ("吾輩は猫である。名前はまだない。どこで生れたかとんと見当がつかぬ。", "今日", "pdf"),
        ("親譲の無鉄砲で小供の時から損ばかりしてい", "昨日", "txt"),
        ("恥の多い生涯を送って来ました。自分には、人間の生活というものが、見当つかないのです。", "昨日", "txt"),
        ("山路を登りながら、こう考えた。智に働けば角が立つ。情に棹させば流される。", "2日前", "txt"),
        ("木曾路はすべて山の中である。あるところは岨づたいに行く崖の道であり", "3日前", "epub"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(files, id: \.0) { file in
                        HStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .frame(width: 50, height: 50)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.0)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                HStack {
                                    Text(file.1)
                                    Text("・")
                                    Text(file.2)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 設定画面コンテンツ
struct SettingsContent: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
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
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - PDF読み上げ画面コンテンツ
struct PDFReadingContent: View {
    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
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
            .padding(.top, 44)
            .background(Color(.systemBackground))

            // PDFテキスト表示エリア
            ScrollView {
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
            }
            .background(Color(.systemBackground))

            // ページ表示
            Text("1 / 12 ページ")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
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
#endif
