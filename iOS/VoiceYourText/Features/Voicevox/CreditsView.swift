import SwiftUI

/// クレジット。キャラ音声（VOICEVOX）は各キャラの利用規約で、アプリ内の分かる場所への表記が求められている。
struct CreditsView: View {
    var body: some View {
        List {
            Section {
                ForEach(VoicevoxCatalog.voices) { voice in
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

            Section {
                Link(destination: URL(string: "https://voicevox.hiroshiba.jp/term/")!) {
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
        .navigationTitle("クレジット")
        .navigationBarTitleDisplayMode(.inline)
    }
}
