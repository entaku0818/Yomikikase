import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import Dependencies

struct EPUBPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    let onTextExtracted: (String) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showingFilePicker = false

    @Dependency(\.epubImport) var epubImport

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.brown)

                VStack(spacing: 8) {
                    Text("EPUBファイルを選択")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("DRMのないEPUBファイルのテキストを読み上げます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let error = errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("テキストを抽出中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: { showingFilePicker = true }) {
                        Label("EPUBファイルを選択", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brown)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("本 (EPUB)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.epub],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    isLoading = true
                    errorMessage = nil
                    Task {
                        do {
                            let text = try await epubImport.extractText(url)
                            await MainActor.run {
                                isLoading = false
                                dismiss()
                                onTextExtracted(text)
                            }
                        } catch {
                            await MainActor.run {
                                isLoading = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
