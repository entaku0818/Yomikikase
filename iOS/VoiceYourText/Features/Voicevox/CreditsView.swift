import SwiftUI
import Dependencies

/// クレジット。キャラ音声（VOICEVOX）は各キャラの利用規約で、アプリ内の分かる場所への表記が求められている。
struct CreditsView: View {
    @Dependency(\.voicevox) private var voicevox
    @State private var catalog: VoicevoxCatalog?
    @State private var isLoading = true
    @State private var failed = false
    @State private var reload = 0
    var body: some View {
        List {
            Section {
                if isLoading && catalog == nil { ProgressView() }
                if failed { Button("再試行") { reload += 1 } }
                ForEach(catalog?.credits ?? []) { voice in
                    if let url = URL(string: voice.termsUrl) {
                        Link(destination: url) {
                            HStack {
                                Text(voice.credit)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("キャラ音声")
            } footer: {
                Text("キャラ音声は VOICEVOX を使って作っています。読み上げる文章は各キャラクターの利用規約に沿ったものにしてください。")
            }

            if let catalog, let termsURL = URL(string: catalog.termsUrl) {
                Section {
                    Link(destination: termsURL) {
                        HStack {
                            Text("VOICEVOX 利用規約")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task(id: reload) {
            if catalog == nil { catalog = voicevox.cachedCatalog() }
            isLoading = true
            failed = false
            do { catalog = try await voicevox.catalog() }
            catch { if !Task.isCancelled { failed = true } }
            isLoading = false
        }
        .navigationTitle("クレジット")
        .navigationBarTitleDisplayMode(.inline)
    }
}
