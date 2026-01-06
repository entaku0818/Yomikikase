import SwiftUI

#if DEBUG
struct ScreenshotView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // コンテンツ
            switch selectedTab {
            case 0:
                MockHomeView()
            case 1:
                MockMyFilesView()
            case 2:
                MockSettingsView()
            default:
                MockHomeView()
            }

            // タブバー
            HStack {
                TabItem(icon: "house.fill", title: "ホーム", isSelected: selectedTab == 0)
                    .onTapGesture { selectedTab = 0 }
                Spacer()
                TabItem(icon: "doc.fill", title: "マイファイル", isSelected: selectedTab == 1)
                    .onTapGesture { selectedTab = 1 }
                Spacer()
                TabItem(icon: "gearshape.fill", title: "設定", isSelected: selectedTab == 2)
                    .onTapGesture { selectedTab = 2 }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
            .overlay(Divider(), alignment: .top)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
    }
}

struct TabItem: View {
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

// MARK: - ホーム画面
struct MockHomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("読み上げ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 10)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                GridItem2(icon: "doc.text.fill", title: "テキスト", color: .blue, isEnabled: true)
                GridItem2(icon: "doc.richtext.fill", title: "PDF", color: .red, isEnabled: true)
                GridItem2(icon: "externaldrive.fill", title: "Gドライブ", color: .gray, isEnabled: false)
                GridItem2(icon: "book.fill", title: "Kindle", color: .gray, isEnabled: false)
                GridItem2(icon: "books.vertical.fill", title: "本", color: .gray, isEnabled: false)
                GridItem2(icon: "camera.fill", title: "スキャン", color: .gray, isEnabled: false)
                GridItem2(icon: "link", title: "リンク", color: .gray, isEnabled: false)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct GridItem2: View {
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

// MARK: - マイファイル画面
struct MockMyFilesView: View {
    let files = [
        ("親譲の無鉄砲で小供の時から損ばかりしてい", "今日", "txt"),
        ("恥の多い生涯を送って来ました。自分", "今日", "txt"),
        ("国境の長いトンネルを抜けると雪国であった", "今日", "txt"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("マイファイル")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 10)

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

// MARK: - 設定画面
struct MockSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("設定")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .padding(.top, 44)
                .background(Color(.systemBackground))

            GeometryReader { geo in
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * 0.6, height: 3)
            }
            .frame(height: 3)

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
