# iOS 1.4.8（43）審査申請記録

- 申請日: 2026-10-21（日本時間）
- App Store Connect: 6478449537 / com.entaku.VoiceYourText
- 確認済み状態: WAITING_FOR_REVIEW
- ビルド処理状態: VALID
- 公開方式: 審査通過後に手動公開

## 変更内容

- 評価案内と設定のサポート欄から開ける、3問の任意回答アンケートを追加。
- 既存のフィードバック送信先に `[Usage Survey v1]` を付けて回答を保存。
- 入力上限・二重送信防止・送信失敗時の入力保持と再送に対応。
- 日英のASO掲載文と13言語のリリースノートを更新。

## 検証と成果物

- 関連テスト12件成功（UsageSurveyTests 4件、ReviewRequestTests 8件）。
- Releaseアーカイブ、IPA書き出し、アップロード、審査提出が成功。
- ローカル検証・アーカイブでは既存Crashlyticsスクリプトの制限を避けるため、コマンドに `ENABLE_USER_SCRIPT_SANDBOXING=NO` を指定。
- ソースコミット: `d7259ce`
- アーカイブ: `iOS/build/VoiceYourText-1.4.8-43.xcarchive`
- IPA: `iOS/build/export-1.4.8-43/VoiceYourText.ipa`
- アップロード受付ID: `eaa849b2-3334-4753-a6a8-3de9d70c21d6`

ビルド成果物は再検証・再利用のため保存。Androidの作業中変更は含めていない。
