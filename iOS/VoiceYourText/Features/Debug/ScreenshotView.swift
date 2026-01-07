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
                MockScreenWithTopTab(title: "マイファイル") {
                    MyFilesContent()
                }
            case 3:
                MockScreenWithTopTab(title: "設定") {
                    SettingsContent()
                }
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
                GridItemView(icon: "externaldrive.fill", title: "Gドライブ", color: .gray, isEnabled: false)
                GridItemView(icon: "book.fill", title: "Kindle", color: .gray, isEnabled: false)
                GridItemView(icon: "books.vertical.fill", title: "本", color: .gray, isEnabled: false)
                GridItemView(icon: "camera.fill", title: "スキャン", color: .gray, isEnabled: false)
                GridItemView(icon: "link", title: "リンク", color: .gray, isEnabled: false)
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

// MARK: - ハイライト読み上げ画面コンテンツ
struct HighlightReadingContent: View {
    let sampleText = "国境の長いトンネルを抜けると雪国であった。夜の底が白くなった。信号所に汽車が止まった。"

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー（モック）
            HStack {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                Spacer()
                Text("読み上げ")
                    .font(.headline)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .padding(.top, 44)
            .background(Color(.systemBackground))

            // テキストエリア
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ハイライト付きテキスト
                    HStack(spacing: 0) {
                        Text("国境の長い")
                        Text("トンネル")
                            .foregroundColor(.white)
                            .padding(.horizontal, 2)
                            .background(Color.orange)
                        Text("を抜けると雪国であった。")
                    }
                    .font(.title3)
                    Text("夜の底が白くなった。信号所に汽車が止まった。")
                        .font(.title3)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))

            Spacer()

            // 再生コントロール
            VStack(spacing: 16) {
                // プログレスバー
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geo.size.width * 0.3, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                .padding(.horizontal)

                // コントロールボタン（モック）
                HStack(spacing: 40) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(.primary)

                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

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

// MARK: - マイファイル画面コンテンツ
struct MyFilesContent: View {
    let files = [
        ("親譲の無鉄砲で小供の時から損ばかりしてい", "今日", "txt"),
        ("恥の多い生涯を送って来ました。自分", "今日", "txt"),
        ("国境の長いトンネルを抜けると雪国であった", "今日", "txt"),
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
                            Text("声の速さ")
                            HStack {
                                Image(systemName: "tortoise.fill")
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(0.4))
                                    .tint(.blue)
                                Image(systemName: "hare.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))

                        Divider().padding(.leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("声の高さ")
                            HStack {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(0.35))
                                    .tint(.blue)
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.secondary)
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

#Preview {
    ScreenshotView()
}
#endif
