import SwiftUI
import ComposableArchitecture
import Dependencies

/// 青空文庫の名作を選んでダウンロードする画面。
///
/// 初回起動直後で手元に読ませたいテキストが無くても、その場で読み上げを体験できるようにするための入口。
/// ダウンロードしたテキストは既存のテキスト取り込みと同じく `TextInputView` に流し、マイファイルに保存する。
struct AozoraLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let onTextDownloaded: (String) -> Void

    @State private var catalog: AozoraCatalog = .empty
    @State private var searchText = ""
    @State private var downloadingWorkId: String?
    @State private var errorMessage: String?
    @State private var loadError: String?

    @Dependency(\.aozora) var aozora
    @Dependency(\.analytics) var analytics

    private var visibleWorks: [AozoraWork] {
        catalog.filtered(by: searchText)
    }

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    errorState(message: loadError)
                } else {
                    workList
                }
            }
            .navigationTitle("名作を聴く")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "作品名・著者名で検索")
        }
        .onAppear(perform: loadCatalog)
    }

    // MARK: - Subviews

    private var workList: some View {
        List {
            Section {
                ForEach(visibleWorks) { work in
                    workRow(work)
                }
            } header: {
                Text("著作権保護期間が満了した名作を、青空文庫からダウンロードして読み上げます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(nil)
                    .padding(.bottom, 4)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("出典：青空文庫（https://www.aozora.gr.jp/）")
                    Text("本文は青空文庫が公開しているテキストファイルを、読み上げ用にルビ・注記を取り除いて利用しています。")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if visibleWorks.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .alert("ダウンロードできませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func workRow(_ work: AozoraWork) -> some View {
        Button {
            download(work)
        } label: {
            workRowLabel(work)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(downloadingWorkId != nil)
    }

    private func workRowLabel(_ work: AozoraWork) -> some View {
        HStack(spacing: 12) {
            workIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(work.displayTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(work.author)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            downloadIndicator(for: work)
        }
        .contentShape(Rectangle())
    }

    private var workIcon: some View {
        Image(systemName: "text.book.closed.fill")
            .font(.system(size: 18))
            .foregroundColor(AppTheme.primary)
            .frame(width: 40, height: 40)
            .background(AppTheme.primarySoft)
            .cornerRadius(11)
    }

    @ViewBuilder
    private func downloadIndicator(for work: AozoraWork) -> some View {
        if downloadingWorkId == work.id {
            ProgressView()
        } else {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.primary)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadCatalog() {
        guard catalog.works.isEmpty else {
            return
        }
        Task {
            do {
                let loaded = try await aozora.loadCatalog()
                await MainActor.run {
                    catalog = loaded
                    loadError = nil
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func download(_ work: AozoraWork) {
        guard downloadingWorkId == nil else {
            return
        }
        downloadingWorkId = work.id
        errorMessage = nil
        analytics.logEvent("aozora_download_started", [
            "work_id": work.id,
            "title": work.title
        ])

        Task {
            do {
                let text = try await aozora.downloadText(work)
                await MainActor.run {
                    downloadingWorkId = nil
                    analytics.logEvent("aozora_download_completed", [
                        "work_id": work.id,
                        "text_length": text.count
                    ])
                    dismiss()
                    onTextDownloaded(text)
                }
            } catch {
                await MainActor.run {
                    downloadingWorkId = nil
                    errorMessage = error.localizedDescription
                    analytics.logEvent("aozora_download_failed", [
                        "work_id": work.id,
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }
}

#Preview {
    AozoraLibraryView { _ in }
}
