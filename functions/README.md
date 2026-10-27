# Feedback Cloud Function

`index.js` の `submitFeedback` は `asia-northeast1` のHTTP関数。POSTされたフィードバックをFirestoreの `feedback` に保存し、設定されていればSlackへ通知する。

## 検証

`functions/` で実行する。

```bash
npm ci
node --check index.js
npm run lint
```

CIはNode.js 20で構文・lintを検証する。デプロイ先ランタイムはルートの `firebase.json` で `nodejs22` を指定している。`npm test` は未実装で、動作テストのゲートは現時点でない。

## 実行時環境変数

| 変数 | 必要な場面 | 挙動 |
| --- | --- | --- |
| `SLACK_WEBHOOK_URL` | Slack通知を利用する場合 | Incoming WebhookのURL。未設定なら警告を出して通知だけをスキップし、Firestoreへの保存は継続する |
| `APP_CHECK_ENFORCED` | App Checkを必須化する場合 | 文字列 `true` のとき、トークン無しも401で拒否。それ以外は監視モードで受理する。不正トークンはどちらのモードでも401 |

関数はこれらを `process.env` から取得する。デプロイ先の環境変数として設定し、Webhook URLをリポジトリやログへ記載しない。Firestoreへの書き込み権限は実行サービスアカウントの権限として用意する。認証情報は `initializeApp()` が利用する実行環境の認証から取得する。

App Check必須化の前に、Firebase ConsoleでクライアントのApp Checkを設定し、実機のトークン取得とサーバ検証を確認する。Firestoreの `appCheck` フィールド（`valid` / `missing`）で利用状況を確認する。監視モードはトークン無しのアクセスを遮断しない。導入の残作業は [Issue #83](https://github.com/entaku0818/Yomikikase/issues/83) を参照。

## デプロイ

Firebase CLIにログインし、対象プロジェクトと上記設定を確認した上で、リポジトリルートから実行する。

```bash
firebase deploy --only functions:submitFeedback --project <対象プロジェクトID>
```

デプロイ後は実際のクライアントから送信し、Firestoreへの保存と、通知を有効にした場合のSlack到着を確認する。メッセージは最大2000文字。Slack通知はベストエフォートで、通知が失敗しても保存済みなら成功応答を返す。

CIの実行条件とローカル開発全般は [開発ガイド](../docs/development.md) を参照。
