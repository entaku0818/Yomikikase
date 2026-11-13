# App Store 全50ロケール対応

2026-10-29。アプリ内翻訳・ストア情報・スクリーンショットをApp Storeの全50ロケールに展開。
Apple公式一覧: https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes

## 管理するファイル

- `iOS/fastlane/locales.json`: 50のストアロケールとアプリの言語コードの対応。
- `iOS/VoiceYourText/Localization/Localizable.xcstrings`: 399項目。既存訳を保持し不足分を補完。
- `iOS/VoiceYourText/Localization/*.lproj/InfoPlist.strings`: アプリ表示名・カメラ・パーソナルボイス権限の説明。
- `iOS/fastlane/metadata/<locale>/`: 名前・サブタイトル・説明・キーワード・プロモーション・リリースノート。
- `iOS/fastlane/screenshot-locales.json`: 撮影時の言語と実際の画面ラベル。
- `iOS/fastlane/screenshot-captions.json`: 各言語のスクショ見出し。
- `iOS/VoiceYourText/Features/Debug/ScreenshotSamples.json`: 追加言語の撮影用サンプル。元の13言語は既存のSwiftフィクスチャを使用。

## 翻訳について

ユーザーはGoogle翻訳へのUI・ストア・スクショ文言の送信を明示的に許可し、停止後に再開を指示した。送信したのは翻訳対象の文言のみ。コード・認証情報・利用者データは送信していない。

追加の機械翻訳は `needs_review` で保持。再生・ホーム・本・音程などの多義語を32言語で修正。ネイティブ話者による全文章レビューは未実施。`translation-review.json` は翻訳下訳生成時のレビュー対象を記録している。

全50ロケールはUI・ストア情報の範囲であり、音声合成の全50言語対応を意味しない。標準音声は端末依存、Kokoroは日英、VOICEVOXは日本語。ストア説明にもこの違いを明記している。

## 検証と撮影

```bash
python3 iOS/scripts/validate_localizations.py
xcodebuild build-for-testing -project iOS/VoiceYourText.xcodeproj -scheme VoiceYourText \
  -configuration Debug -destination 'platform=iOS Simulator,id=<iPhone UDID>' \
  -derivedDataPath iOS/build/ShotsDD -skipMacroValidation -skipPackagePluginValidation \
  SWIFT_EMIT_LOC_STRINGS=NO CODE_SIGNING_ALLOWED=NO
bash iOS/scripts/capture_all_locales.sh <iPhone UDID> IPHONE_69
bash iOS/scripts/capture_all_locales.sh <13-inch iPad UDID> IPAD_PRO_3GEN_129
swiftc iOS/scripts/compose_all_locales.swift -o /tmp/narrator-compose
/tmp/narrator-compose iOS/fastlane/screenshot-captions.json \
  iOS/build/all_locale_screenshots/IPHONE_69 iOS/build/all_locale_screenshots/final
/tmp/narrator-compose iOS/fastlane/screenshot-captions.json \
  iOS/build/all_locale_screenshots/IPAD_PRO_3GEN_129 iOS/build/all_locale_screenshots/final
python3 iOS/scripts/validate_localizations.py --screenshots
```

撮影はホーム・マイファイル・設定の実画面。DEBUG専用のメモリ内Core Dataを使い、言語ごとのサンプルを分離する。元のPDFが蓄積しないようバッチでは単一のサンプルPDFを更新する。`SHOT_MANIFEST` に一部ロケールだけのJSONを渡すと部分再撮影できる。

合成はmacOS標準のテキスト描画を使い、アラビア語・ヘブライ語・ウルドゥー語のRTLと各文字体系のフォントフォールバックに対応。実画面を背景・現地語キャプションに配置し、RGB PNGを出力する。

出力と検証ログを `iOS/build/` に保持。App Store Connectへのアップロード・公開は行っていない。

## 2026-10-29 検証結果

- 50ロケール・399エントリのUI、権限説明、ストア情報を用意。翻訳欠落・書式指定子・文字数制限の検証は0エラー。
- `build-for-testing` 成功。音声ガイドのユニットテスト9件成功。
- iPhone / iPadのバッチ撮影テスト成功（再撮影43ロケール＋修正影響のない撮影済み7ロケール、各3画面）。
- 撮影時だけ開発メニューを非表示。iPadの合成画像はOS言語に依存するステータスバー上端50pxを除き、実画面の縦横比を維持。
- 機械翻訳には言語レビューが必要。`translation-review.json` の `uiEntriesAwaitingReview` が修正後の残件数。
- スクショの生画像・合成画像は `iOS/build/all_locale_screenshots/`、ビルドとテストのログは `iOS/build/localization-validation/`。
- 合成後の300枚を `iOS/fastlane/screenshots/<store-locale>/` に配置済み。`validate_localizations.py --screenshots` は0エラー。
- 元のスクショは `iOS/build/screenshots-before-all50/` にバックアップ済み。
- 全画像の確認用一覧: `iOS/build/all_locale_screenshots/final/index.html`。
- 再生成時は合成後の各言語ディレクトリ内PNGを、バックアップしたうえで対応する `fastlane/screenshots` に配置してから `--screenshots` を実行する。

## 申請状況の更新

2026-10-29、ユーザー指示で1.4.11（47）をApp Store審査に提出。全50ロケール・スクショ300枚の登録と処理完了を確認。状態はWAITING_FOR_REVIEW、手動リリース。詳細は [提出記録](../releases/1.4.11.md)。
