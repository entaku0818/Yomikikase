# voicevox-server

アプリの「キャラ音声」を作るサーバー。Cloud Run（東京）で、VOICEVOX 公式エンジンの前に中継（gateway）を置く。

```
アプリ ──HTTPS──> gateway (:8080) ──127.0.0.1──> VOICEVOX engine (:50021)
          App Check          │
          X-User-ID          ├─ RevenueCat: プレミアム会員か
                             └─ Firestore: 月の文字数（voicevox_usage/{userId}_{YYYY-MM}）
```

- エンジンは認証を持たないので外に出さない。同じインスタンスのサイドカーとして動かす
- 声は `internal/voices` の許可リストだけ。足すときはキャラの利用規約（商用可否・申請要否・クレジット書式）を先に確認する
- 月の上限: 無料 5,000字 / プレミアム 200,000字（日本時間の月初にリセット）。合成に失敗した分は戻す
- 音声は 64kbps AAC（m4a）で返す。WAV だと 1回18分の読み上げで約52MBになるため

## API

すべて `X-Firebase-AppCheck`（App Check トークン）と `X-User-ID`（RevenueCat の App User ID）が必要。`/v1/voices` だけは不要。

| メソッド | パス | 内容 |
|---|---|---|
| GET | `/v1/voices` | 使える声とクレジット表記 |
| GET | `/v1/quota` | 今月の使用量・上限・リセット日時 |
| POST | `/v1/synthesize` | `{"text","speakerId","speedScale"?,"pitchScale"?}` → `{"audio"(base64 m4a),"format","duration","phrases":[{kana,start,end}],"usage"}` |

1回の `text` は300字まで。アプリは文ごとに分けて送り、最初の文ができたら再生を始める。
上限を超えると 429 `quota_exceeded`（`usage` 付き）。

## 手元で動かす

```bash
docker run -d --rm --name voicevox -p 127.0.0.1:50021:50021 voicevox/voicevox_engine:cpu-0.25.2
LOCAL_DEV=1 PORT=18080 go run ./cmd/gateway    # App Check を検証せず、使用量はメモリに持つ
curl -s -X POST localhost:18080/v1/synthesize -H 'X-Firebase-AppCheck: x' -H 'X-User-ID: premium-user' \
  -d '{"text":"こんにちは","speakerId":14}'
```

テスト: `go test ./...`。実エンジンで再生位置の計算を確かめるときは `VOICEVOX_ENGINE_URL=http://127.0.0.1:50021 go test ./internal/voicevox/`。

## デプロイ

```bash
voicevox-server/scripts/deploy.sh setup    # 初回だけ（RevenueCat のシークレットキーを標準入力で渡す）
voicevox-server/scripts/deploy.sh deploy
```
