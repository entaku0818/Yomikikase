# KokoroSwift

Kokoro音声モデルをMLXで端末上実行するローカルSwiftパッケージ。Swift tools 6.0、iOS 18+ / macOS 14+を指定する。アプリ側の入口は `Features/KokoroTTS/KokoroTTSClient.swift`、モデル管理は同ディレクトリの `KokoroModelManager.swift`。

## 依存関係

`Package.swift` がMLX / MLXNN / MLXRandom / MLXFFT（mlx-swift 0.30.x、最低0.30.6）、MisakiSwiftの固定リビジョンのフォーク、MLXUtilsLibrary 0.0.6を参照する。MisakiSwiftフォークはSimulatorビルド用のMLX弱リンク修正を取り込むため使用している。`Resources` のconfigと辞書等はパッケージリソースとしてバンドルされ、モデル重みと音声埋め込みは別途ダウンロードする。

## セットアップ

1. XcodeでVoiceYourTextプロジェクトのSwift Package依存を解決する。
2. アプリのKokoro音声設定からモデルをダウンロードする。アプリの `KokoroModelManager.download()` が次の2ファイルを保存する。
3. ダウンロード完了後、Kokoroを有効にして対応する日本語・英語の音声で試す。

保存場所はアプリのサンドボックス内の `Library/Application Support/KokoroTTS/`。コードからは `KokoroModelManager.storageDirectory()` で取得する。

| 保存名 | 現在の取得元（コード定義） |
| --- | --- |
| `kokoro-v1_0.safetensors` | `media.githubusercontent.com/media/mlalma/KokoroTestApp/main/Resources/kokoro-v1_0.safetensors` |
| `voices.npz` | `voiceyourtext.web.app/kokoro/voices-v1.npz` |

開発時に手動配置する場合も同じサンドボックス内・同じファイル名を使う。モデルはGit LFSのポインタではなく実データが必要。音声埋め込みは日本語の `jf_alpha` / `jm_kumo` を含む配布版を使う。生成手順はリポジトリの `scripts/build_kokoro_voices.py`。ダウンロードURLと仕様の正本はModelManagerで、ここへの記載は外部URLの稼働保証ではない。

## アプリ側APIと検証

`@Dependency(\.kokoroTTS)` から `isAvailable()` と `synthesize(text, voice, speed)` を利用する。後者は24kHz・モノラルのWAV `Data` を返し、speedは1.0が通常速度。AVSpeechのrateはそのまま渡さず、アプリの `KokoroPlaybackParams` を使って変換する。

`isAvailable()` はファイルの存在と音声ファイルのヘッダーを確認するもので、推論成功を保証しない。未ダウンロード・モデル読込失敗・合成失敗は呼び出し側で処理する。モデル利用にはMetal/MLX実行環境が必要で、ビルド成功と実機での音質確認は別に行う。

アプリのビルド・テストは [開発ガイド](../../../docs/development.md) を参照（リポジトリルートから実行）。このパッケージ単体にはテストターゲットがない。モデル取得なしで実行可能なアプリ側のモデル管理・再生パラメータテストと、実機の日本語/英語合成確認を分けて扱う。
