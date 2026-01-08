# VoiceYourText Cloud Run Service

Firebase Functionsと同等の機能をGoで実装したCloud Runサービスです。

## エンドポイント

| エンドポイント | メソッド | 説明 |
|---------------|---------|------|
| `/getVoices` | GET | 利用可能な音声一覧を取得 |
| `/generateAudio` | POST | テキスト処理（Gemini AI使用） |
| `/generateAudioWithTTS` | POST | 音声生成（Google Cloud TTS使用） |
| `/health` | GET | ヘルスチェック |

## ローカル開発

### 必要な環境

- Go 1.22以上
- Google Cloud SDK（`gcloud` CLI）
- Google Cloud プロジェクト（Text-to-Speech API有効化済み）

### 環境変数の設定

```bash
cp .env.example .env
# .envファイルを編集して必要な値を設定
```

### ローカル実行

```bash
# 依存関係の解決
go mod tidy

# サーバー起動
go run cmd/server/main.go
```

### ビルド・テスト（Makefile）

```bash
# ビルド
make build

# テスト実行
make test

# カバレッジ付きテスト
make test-coverage

# リンター
make lint

# ローカル実行
make run

# Docker ビルド
make docker-build
```

## Cloud Runへのデプロイ

### 現在のgcloud設定

```
Project:  aso-tool-prod
Region:   asia-northeast1
Account:  entaku19890818@gmail.com
Service:  voiceyourtext-tts
URL:      https://voiceyourtext-tts-671942133800.asia-northeast1.run.app
```

### 方法1: デプロイスクリプト（推奨）

```bash
./scripts/deploy.sh
```

### 方法2: 手動デプロイ

```bash
# gcloud設定の確認
gcloud config list

# 必要に応じて設定
gcloud config set project aso-tool-prod
gcloud config set compute/region asia-northeast1

# ビルド & プッシュ
gcloud builds submit --tag gcr.io/aso-tool-prod/voiceyourtext-tts

# Cloud Runにデプロイ
gcloud run deploy voiceyourtext-tts \
  --image gcr.io/aso-tool-prod/voiceyourtext-tts \
  --region asia-northeast1 \
  --platform managed \
  --allow-unauthenticated
```

### 方法3: 環境変数付きデプロイ

```bash
gcloud run deploy voiceyourtext-tts \
  --image gcr.io/aso-tool-prod/voiceyourtext-tts \
  --region asia-northeast1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "STORAGE_BUCKET_NAME=your-bucket-name,GEMINI_API_KEY=your-api-key"
```

## API仕様

### GET /getVoices

利用可能な音声一覧を取得します。

**クエリパラメータ:**
- `language` (オプション): 言語コードでフィルタ（例: `ja-JP`, `en-US`）

**レスポンス例:**
```json
{
  "success": true,
  "voices": [
    {
      "id": "ja-jp-female-a",
      "name": "あかり",
      "language": "ja-JP",
      "gender": "female",
      "description": "明るく優しい女性の声"
    }
  ]
}
```

### POST /generateAudio

テキストをGemini AIで処理します（プレースホルダー機能）。

**リクエストボディ:**
```json
{
  "text": "読み上げるテキスト",
  "language": "ja-JP"
}
```

**レスポンス例:**
```json
{
  "success": true,
  "processedText": "処理されたテキスト",
  "originalText": "読み上げるテキスト",
  "language": "ja-JP",
  "message": "Audio generation completed (placeholder)"
}
```

### POST /generateAudioWithTTS

Google Cloud Text-to-Speech APIを使用して音声を生成します。

**リクエストボディ:**
```json
{
  "text": "読み上げるテキスト",
  "voiceId": "ja-jp-female-a",
  "language": "ja-JP",
  "style": "cheerfully"
}
```

**レスポンス例:**
```json
{
  "success": true,
  "originalText": "読み上げるテキスト",
  "language": "ja-JP",
  "voice": {
    "id": "ja-jp-female-a",
    "name": "あかり",
    "language": "ja-JP",
    "gender": "female",
    "description": "明るく優しい女性の声"
  },
  "style": "cheerfully",
  "audioUrl": "https://storage.googleapis.com/bucket/audio/filename.wav",
  "filename": "audio/ja-jp-female-a_1234567890_uuid.wav",
  "mimeType": "audio/wav",
  "message": "Audio generated and saved successfully"
}
```

**エラーレスポンス:**
- `405`: メソッドが許可されていない
- `400`: テキストが空、テキストが長すぎる（5000文字制限）、無効なvoiceId
- `500`: TTS生成エラー、ストレージエラー

## 利用可能な音声

### English (US)
| ID | Name | Gender | Description |
|---|---|---|---|
| `en-us-female-a` | Emma | Female | Clear American female voice |
| `en-us-male-b` | John | Male | Professional American male voice |
| `en-us-female-c` | Sarah | Female | Warm American female voice |
| `en-us-male-d` | Mike | Male | Deep American male voice |

### Japanese
| ID | Name | Gender | Description |
|---|---|---|---|
| `ja-jp-female-a` | あかり | Female | 明るく優しい女性の声 |
| `ja-jp-male-b` | ひろし | Male | 穏やかな男性の声 |

## 必要なGoogle Cloud APIs

- Cloud Text-to-Speech API
- Cloud Storage API
- Cloud Run API

## 環境変数

| 変数名 | 必須 | 説明 |
|-------|------|------|
| `PORT` | No | サーバーポート（Cloud Runが自動設定、デフォルト8080） |
| `STORAGE_BUCKET_NAME` | Yes | Cloud Storageバケット名 |
| `GEMINI_API_KEY` | No | Gemini API キー（generateAudioで使用） |
| `PROJECT_ID` | No | Google Cloudプロジェクト ID |

## Firebase Functionsからの移行

このCloud Runサービスは、`server/`ディレクトリのFirebase Functionsと完全に互換性があります。

エンドポイントのURLを更新するだけで移行できます:

**Firebase Functions:**
```
https://us-central1-voiceyourtext.cloudfunctions.net/getVoices
```

**Cloud Run:**
```
https://voiceyourtext-tts-xxxxx-an.a.run.app/getVoices
```
