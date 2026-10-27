# Legacy Cloud Run configuration

旧クラウドTTSサービスのコード・ワークフローを保守するための設定一覧。iOSの現在のxcconfigには旧クラウドTTSのキーを追加しない。実装の正本は `cloudrun/cmd/server/main.go` と `cloudrun/internal/jobs/queue.go`。

| 実行時変数 | 用途・設定元 |
| --- | --- |
| `GOOGLE_CLOUD_PROJECT` | FirestoreとCloud Tasksのプロジェクト。ワークフローの `PROJECT_ID` から設定 |
| `CLOUD_TASKS_LOCATION` | キューのリージョン。現在のワークフローでは `asia-northeast1` |
| `CLOUD_TASKS_QUEUE` | 事前作成したCloud Tasksキュー名。現在は `tts-jobs` |
| `SERVICE_URL` | 稼働するCloud RunサービスのベースURL。キューが `/jobs/process` を付加して呼び出す |
| `API_KEY` | API認証とキューからのリクエストの `X-API-Key`。GitHub Secret `CLOUDRUN_API_KEY` から設定 |
| `STORAGE_BUCKET_NAME` | 音声ファイル保存先。対応するGitHub Secretから設定 |
| `GEMINI_API_KEY` | Gemini処理用。対応するGitHub Secretから設定 |
| `PORT` | HTTPポート。未指定時8080 |

`PROJECT_ID` はActions内の変数名であり、Goプロセスが読むのは `GOOGLE_CLOUD_PROJECT`。`.github/workflows/deploy-cloudrun.yml` の現在のプロジェクトは `voiceyourtext`、サービス名は `voiceyourtext-tts`。ローカルのgcloud既定プロジェクトとは区別する。

デプロイ認証にはGitHub Secret `GCP_SA_KEY` を使用する。実行サービスアカウントにはFirestore、Cloud Tasks、Storageなど利用するサービスの権限が必要。キューとバケットを先に用意し、実行時の認証も設定する。

ワークフローは既存サービスをdescribeして `SERVICE_URL` を取得する。初回作成でURLが空のときは、デプロイ後に取得したサービスURLを設定してから非同期ジョブを検証する。空文字のままでは正しい処理先にならない。

`cloudrun/**` のmainへのpushは自動デプロイを起動する。設定説明のみを変更する場合はこの文書を更新する。秘密値は文書やログに書かない。この文書更新で実際の設定変更・デプロイは行わない。
