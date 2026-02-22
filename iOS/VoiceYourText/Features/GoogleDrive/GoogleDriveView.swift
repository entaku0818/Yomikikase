import SwiftUI
import ComposableArchitecture

struct GoogleDriveView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<Speeches.State, Speeches.Action>
    let onTextExtracted: (String) -> Void

    @State private var gdStore = Store(initialState: GoogleDriveFeature.State()) {
        GoogleDriveFeature()
    }

    var body: some View {
        NavigationView {
            WithViewStore(gdStore, observe: { $0 }) { viewStore in
                Group {
                    if !viewStore.isSignedIn {
                        signInView(viewStore: viewStore)
                    } else {
                        fileListView(viewStore: viewStore)
                    }
                }
                .navigationTitle("Gドライブ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    if viewStore.isSignedIn {
                        ToolbarItem(placement: .destructiveAction) {
                            Button("サインアウト") {
                                viewStore.send(.view(.signOutTapped))
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .onAppear {
                    viewStore.send(.view(.onAppear))
                }
                .onChange(of: viewStore.didExtractText) { _, didExtract in
                    if didExtract {
                        dismiss()
                        onTextExtracted(viewStore.extractedText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func signInView(viewStore: ViewStore<GoogleDriveFeature.State, GoogleDriveFeature.Action>) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "externaldrive.badge.person.crop")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Googleドライブ")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Googleアカウントにサインインして\nドキュメントを読み上げます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = viewStore.errorMessage {
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

            if viewStore.isLoading {
                ProgressView()
            } else {
                Button(action: { viewStore.send(.view(.signInTapped)) }) {
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                        Text("Googleでサインイン")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func fileListView(viewStore: ViewStore<GoogleDriveFeature.State, GoogleDriveFeature.Action>) -> some View {
        Group {
            if viewStore.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("ファイルを読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if viewStore.files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("テキストファイルが見つかりません")
                        .foregroundColor(.secondary)
                    Text("Google Docs、テキスト、Markdownファイルが表示されます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List(viewStore.files) { file in
                    Button(action: {
                        viewStore.send(.view(.fileTapped(file)))
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: mimeTypeIcon(file.mimeType))
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)

                                if let date = file.modifiedTime {
                                    Text(date, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if viewStore.isLoadingFile {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if let error = viewStore.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
    }

    private func mimeTypeIcon(_ mimeType: String) -> String {
        if mimeType.contains("google-apps.document") {
            return "doc.text.fill"
        } else if mimeType.contains("markdown") {
            return "doc.richtext"
        } else {
            return "doc.plaintext"
        }
    }
}
