# iOS 1.4.10（46）リリース記録

- 作業日: 2026-10-28（日本時間）
- App Store Connect: 6478449537 / com.entaku.VoiceYourText
- バージョンID: d1dd2529-ed97-4aca-9293-a2d66a87c144
- 公開方式: 審査通過後に自動公開（AFTER_APPROVAL）
- 公開済みの前版: 1.4.9（45）。ストアでは公開済みだが、作業開始時のプロジェクト設定は1.4.8（44）だったため更新。

## 変更

- 再生停止・再開時のキャンセルと遅延コールバックの扱いを改善。
- 初期案内の用途タグ・機能説明の英語表示を修正。
- 未使用の色定義を削除。
- 13言語のリリースノートを更新。

## ソースと検証

- ベース: `0a69499`。このコミットのgit archiveにバージョン・リリースノートだけを反映してビルドした。
- 既存の未コミット作業（Android、音声品質、実コンテンツ再生計測など）は含めていない。
- 前段の検証: 初期案内Reducer 14件、ja/enのUIフロー4件、PaywallAnalytics 22件成功。再生キャンセル修正の検証は `quality/playback-2026-10-26.md` を参照。
- Xcode 27.1 / iPhoneOS 27.1 SDKでRelease archive成功。
- 既存Crashlyticsスクリプトの制限を避けるため `ENABLE_USER_SCRIPT_SANDBOXING=NO` をビルド引数に指定。プロジェクト設定は変更していない。
- Swift Packageの固定バージョンは変更なし。
- アーカイブ: `iOS/build/VoiceYourText-1.4.10-46.xcarchive`
- 書き出し設定: `iOS/build/ExportOptions-1.4.10-46.plist`

実機での音質検証と公開後の計測評価は本リリース作業では実施していない。

## アップロード

App Store Connectへのアップロード成功（`EXPORT SUCCEEDED`）。GoogleAppMeasurement、GoogleMobileAds、UserMessagingPlatform、gRPC関連の依存フレームワークにdSYM不足警告あり。これらのクラッシュ解析には制限が残るが、バイナリのアップロードは成功した。

## 最終確認

- 審査提出: 2026-10-28 00:24 JST
- APIで確認した状態: `WAITING_FOR_REVIEW`
- 審査対象: 1.4.10 / build 46（`375c13e7-9291-432c-98da-8d47e31f6d03`、`VALID`）
- 公開方式: `AFTER_APPROVAL`。公開済みではなく、審査待ち。
- 初回提出時に必須項目 `socialMedia` 未回答で拒否されたため、編集対象App Informationの `socialMedia=false` / `socialMediaAgeRestricted=false` のみ補完して再提出。アプリはソーシャルフィードや利用者間交流を提供しない。ほかの既存回答は変更していない。
- 項目の定義: [Appleのソーシャルメディアに関する年齢制限案内](https://developer.apple.com/news/?id=tlur8uvi)。
