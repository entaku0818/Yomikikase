import SwiftUI

#if DEBUG
enum ScreenshotScene: Int, CaseIterable {
    case home = 0
    case settings = 1
    case highlight = 2
    case myFiles = 3

    var title: String {
        switch self {
        case .home: return "ホーム"
        case .settings: return "設定"
        case .highlight: return "読み上げ"
        case .myFiles: return "ファイル"
        }
    }
}

struct ScreenshotView: View {
    @State private var selectedScene: ScreenshotScene = .home

    var body: some View {
        VStack(spacing: 0) {
            // Scene Picker
            Picker("シーン", selection: $selectedScene) {
                ForEach(ScreenshotScene.allCases, id: \.self) { scene in
                    Text(scene.title).tag(scene)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.systemBackground))

            // Screenshot Content
            switch selectedScene {
            case .home:
                MockHomeView()
            case .settings:
                MockSettingsView()
            case .highlight:
                MockHighlightView()
            case .myFiles:
                MockMyFilesView()
            }
        }
    }
}

// MARK: - 1. ホーム画面（読み上げグリッド）
struct MockHomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー風
            Text("読み上げ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

            // グリッド
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                HomeGridItem(icon: "doc.text.fill", title: "テキスト", color: .blue, isEnabled: true)
                HomeGridItem(icon: "doc.richtext.fill", title: "PDF", color: .red, isEnabled: true)
                HomeGridItem(icon: "externaldrive.fill", title: "Gドライブ", color: .gray, isEnabled: false)
                HomeGridItem(icon: "book.fill", title: "Kindle", color: .gray, isEnabled: false)
                HomeGridItem(icon: "books.vertical.fill", title: "本", color: .gray, isEnabled: false)
                HomeGridItem(icon: "camera.fill", title: "スキャン", color: .gray, isEnabled: false)
                HomeGridItem(icon: "link", title: "リンク", color: .gray, isEnabled: false)
            }
            .padding(.horizontal, 20)

            Spacer()

            // タブバー
            MockTabBar(selectedTab: 0)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct HomeGridItem: View {
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

// MARK: - 2. 設定画面
struct MockSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            Text("設定")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))

            // プログレスバー風
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * 0.6, height: 3)
            }
            .frame(height: 3)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 音声設定セクション
                    Text("音声設定")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    VStack(spacing: 0) {
                        // 音声の選択
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

                        // 声の速さ
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

                        // 声の高さ
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

                    // 辞書セクション
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

                    // 言語設定セクション
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

                    // リセットボタン
                    Button(action: {}) {
                        Text("読み上げ設定をデフォルト値に戻す")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }

            // タブバー
            MockTabBar(selectedTab: 2)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 3. ハイライト読み上げ画面
struct MockHighlightView: View {
    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            HStack {
                Button("キャンセル") {}
                    .foregroundColor(.blue)
                Spacer()
                Button("保存") {}
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))

            // テキストエリア
            VStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text("国境の長い")
                    Text("トンネル")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .foregroundColor(.white)
                    Text("を抜けると雪国であった。夜の底が白くなった。信号所に汽車が止まった。")
                }
                .font(.body)
                .lineSpacing(6)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))

            // 停止ボタン
            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.trailing, 30)
                .padding(.bottom, 20)
            }

            // タブバー
            MockTabBar(selectedTab: 0)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 4. マイファイル画面
struct MockMyFilesView: View {
    let files = [
        ("親譲の無鉄砲で小供の時から損ばかりしてい", "今日", "txt"),
        ("恥の多い生涯を送って来ました。自分", "今日", "txt"),
        ("国境の長いトンネルを抜けると雪国であった", "今日", "txt"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            Text("マイファイル")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

            // ファイルリスト
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
            }

            Spacer()

            // タブバー
            MockTabBar(selectedTab: 1)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 共通タブバー
struct MockTabBar: View {
    let selectedTab: Int

    var body: some View {
        HStack {
            TabBarItem(icon: "house.fill", title: "ホーム", isSelected: selectedTab == 0)
            Spacer()
            TabBarItem(icon: "doc.fill", title: "マイファイル", isSelected: selectedTab == 1)
            Spacer()
            TabBarItem(icon: "gearshape.fill", title: "設定", isSelected: selectedTab == 2)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Divider(), alignment: .top
        )
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(title)
                .font(.caption2)
        }
        .foregroundColor(isSelected ? .blue : .gray)
    }
}

#Preview {
    ScreenshotView()
}
#endif
