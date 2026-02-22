import SwiftUI
import ComposableArchitecture
import Dependencies

struct LinkInputView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    let onTextExtracted: (String) -> Void

    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @Dependency(\.webPageFetch) var webPageFetch

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("WebページのURLを入力すると、テキストを抽出して読み上げます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("https://example.com", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                if let error = errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                }

                Button(action: fetchPage) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                            Text("取得中...")
                                .foregroundColor(.white)
                        } else {
                            Text("テキストを取得")
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(isValidURL ? Color.teal : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isValidURL || isLoading)

                Spacer()
            }
            .padding()
            .navigationTitle("リンク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var isValidURL: Bool {
        urlText.lowercased().hasPrefix("https://") && urlText.count > 12
    }

    private func fetchPage() {
        guard let url = URL(string: urlText) else {
            errorMessage = "無効なURLです"
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let text = try await webPageFetch.fetchText(url)
                await MainActor.run {
                    isLoading = false
                    if text.isEmpty {
                        errorMessage = "テキストを取得できませんでした"
                    } else {
                        dismiss()
                        onTextExtracted(text)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
