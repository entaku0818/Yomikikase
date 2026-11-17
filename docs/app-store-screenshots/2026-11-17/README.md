# 1.4.15 スクリーンショット更新

対象は全50言語のiPhone・iPad。各端末の3枚構成を6枚に増やす（合計600枚）。順序は再生中、ホーム、速度調整、PDF、スリープタイマー、ユーザー辞書。日本語の6枚プレビューはユーザー確認済み。

## 再生成

リポジトリルートから実行。キャプションは `iOS/fastlane/screenshot-captions.json` とアプリの文字列カタログから生成する。

```sh
python3 iOS/scripts/prepare_store_screenshots.py
# 先に最新のDebugアプリとUIテストをbuild-for-testingする。
python3 iOS/scripts/capture_store_screenshots.py iphone
python3 iOS/scripts/capture_store_screenshots.py ipad
python3 iOS/scripts/prepare_screenshot_details.py
swiftc iOS/scripts/compose_store_screenshots.swift -o iOS/build/screenshots-2026-11-17/compose
iOS/build/screenshots-2026-11-17/compose iOS/build/screenshots-2026-11-17/captions.json iOS/build/screenshots-2026-11-17/raw iOS/build/screenshots-2026-11-17/final
```

撮影用のデータ・再生状態はDebug専用。実際のアプリ画面を撮り、ハイライト箇所の画像を拡大している。撮影時の音声再生は固定フィクスチャに置き換える。Releaseへの混入はアーカイブした実行ファイルで確認する。

## App Store Connectへの登録

`workflow.py` は1.4.15の編集可能な下書きだけを対象にする。公開中1.4.14の配置と検索結果・ヘッダーの配置は保持する。鍵はリポジトリの既存 `.env` から実行時だけ読み込み、証跡に保存しない。

```sh
python3 docs/app-store-screenshots/2026-11-17/workflow.py snapshot
python3 docs/app-store-screenshots/2026-11-17/workflow.py notes
# 撮影完了分の画像だけ先行転送する場合は upload_ready。
python3 docs/app-store-screenshots/2026-11-17/workflow.py upload
python3 docs/app-store-screenshots/2026-11-17/workflow.py place
python3 docs/app-store-screenshots/2026-11-17/workflow.py verify
python3 docs/app-store-screenshots/2026-11-17/workflow.py downloads
```

画像転送と配置のチェックポイントを保存し、再実行時に再利用する。配置前に600枚の寸法・RGB形式・ハッシュを検証し、配置後に言語・端末・順序を全件照合する。CDN取得画像も全600枚の画素一致を確認する。登録・審査提出・公開はそれぞれ別の状態として記録する。

ビルド、撮影結果、ログ、作業前バックアップは `iOS/build/` に保持する。

`release.py select_build` はApple側でVALIDとなった1.4.15のビルド53を選択する。`release.py submit` は600枚の配置・CDN画素一致・全50言語のリリースノートを再検証した後に審査提出する。公開方法は既存の承認後自動公開を保持する。

撮影で見つかったPDF再生時の状態再生成は、`PDFReaderPresentation` が画面の表示期間中Storeを保持することで修正した。修正前のビルド52と成果物は保持し、配布対象を53に変更した。
