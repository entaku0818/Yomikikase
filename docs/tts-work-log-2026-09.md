# TTS まわり 作業ログ（2026-09-15 〜 09-19）

このセッションでやったこと・残したことの引き継ぎメモ。
関連: [調査レポート](tts-ondevice-research-2026-09-14.md) / [G2P PoC](g2p-poc-2026-09-15.md) / [クラウドTTS撤去](cloud-tts-removal-2026-09-15.md)

---

## 🔴 次にやるべきこと（優先順）

### 1. 実機で Kokoro 日本語が鳴るか確認する（未実施・ブロッカー）
設定 > 音声 から Kokoro モデル(約600MB)をDL → 日本語音声を選んで再生。
**これが通れば日本語オンデバイスAI音声が初めて機能する**ことになる。
DLに600MB要るため、この作業では検証できていない。

### 2. `g` → `ɡ` のバグ修正（未着手・別ワークスペース範囲）
`JapaneseG2PProcessor.swift:86` が ASCII `g`(U+0067) を出すが、Kokoro の語彙にあるのは
IPA `ɡ`(U+0261) だけ。語彙外の文字は Tokenizer が無言で捨てるため、
**日本語の /g/ 音が1つ残らず消えている**（神奈川→カナアワ、助詞の「が」→「あ」）。
PoC実測で現行の語彙外文字は 56個中56個がこれ。変換表14箇所を直すだけ、工数は時間単位。
**Kokoro が実際に鳴るようになった今、これが最優先。**

### 3. 読み下しの追加（未着手・別ワークスペース範囲）
長音（`oɯ`→`oː`、長文で56箇所）、数字（現状 0/8 しか読まれない）、
英略語（`iOS` と `Google` が消える）。すべて `JapaneseG2PProcessor.swift` 内で完結。

### 4. クラウドTTSの後始末（新バージョン公開後）
- `CLOUDRUN_API_KEY` の失効（履歴に平文で残るため削除だけでは無効化されない）
- GCP: Cloud Run `voiceyourtext-tts` / Cloud Tasks `tts-jobs` / GCSバケット削除
- `cloudrun/` ディレクトリ削除
詳細は [cloud-tts-removal-2026-09-15.md](cloud-tts-removal-2026-09-15.md)

---

## このセッションで入れたもの

| commit | 内容 |
|---|---|
| `fd7f656` | クラウドTTSをアプリのコードから完全撤去 |
| `ddd5444` | **Kokoro の日本語音声が1つも配布されていなかった問題を修正**、音声を12→23に拡張 |
| `2a821ff` | `.firebaserc` で Firebase のデフォルトプロジェクトを固定 |
| `6645df6` | PDF/EPUB由来の文中改行を詰めて読み上げの間を自然にする |
| `2430bc7` | 高品質音声のダウンロード案内を実用的な手順に作り直す |

### 判明した重大な事実

**日本語のオンデバイスAI音声は、これまで一度も動いていなかった。**
1. `voices.npz` の取得先 `media.githubusercontent.com/media/...` が **404**
   （LFS専用CDNで、対象ファイルが LFS 管理から外れたため。同ホストの safetensors は 200）
2. その npz の中身は**英語28音声のみ**で `jf_*` / `jm_*` が不在
   → `voiceEmbedding()` が throw → 端末TTSへサイレントフォールバック
3. DL処理がHTTPステータスを見ておらず、404の本文を保存したまま327MBを落としきり、
   「DL完了」と表示しながら `checkDownloaded()` は false を返していた

### 配布構成（現在）

| ファイル | 配布元 | 備考 |
|---|---|---|
| `voices.npz` | **自前** `https://voiceyourtext.web.app/kokoro/voices-v1.npz` | 33音声 / 17MB。実体は `LP/public/kokoro/`、生成は `scripts/build_kokoro_voices.py` |
| `kokoro-v1_0.safetensors` | 第三者 LFS CDN (mlalma/KokoroTestApp) | 327MB。自前に移すと 1,000DLで約$49/月かかるため据え置き |

**npz の中身を変えるときは `voices-v2.npz` を作る。古いクライアントが見る v1 は消さないこと。**

---

## 音声の現状

### Kokoro（オンデバイスAI・要600MB DL）
23音声。公式VOICES.mdのグレード C- 以上を公開（D以下は学習データが数分しかないため除外）。
既出荷の `am_adam`(F+) / `bm_lewis`(D+) は選択中のユーザーがいるため残置。

**日本語は5音声で、これが Kokoro-82M の上限**（6つ目は存在しない）:
`jf_alpha`(C+/凛) `jf_gongitsune`(C/狐) `jf_tebukuro`(C/雪) `jf_nezumi`(C-/芽) `jm_kumo`(C-/雲)

### 端末TTS（AVSpeechSynthesizer）
Kyoko / Otoya / O-ren / Hattori + Enhanced/Premium。
**Enhanced/Premium は Kokoro（最高C+）より自然な可能性が高い**が、
ユーザーが iOS の 設定 > アクセシビリティ > 読み上げコンテンツ > 声 から落とす必要がある。
アプリから直接DLする公式APIは無く、`openSettingsURLString` もアプリ自身の設定ページ止まり。
案内文は `HighQualityVoiceGuide`（純粋ロジック・テスト済み）に集約してある。

---

## 日本語をさらに増やす方法（検討済み・未着手）

1. **端末TTSを使い切る** — 今回の `2430bc7` で導線を強化した。次は効果測定
2. **Kokoro埋め込みのブレンド** — 埋め込みは `voice[tokenCount-1, 0...1, 0...]` で引かれる
   ただのスタイルベクトルなので、線形合成で中間の声を作れる。検証済み:
   - `0.5*jf_alpha + 0.5*jf_tebukuro` → 値域・norm とも正常、元のどちらとも cos 0.89/0.91（＝中間に立つ）
   - 日本語5音声の相互cos: alpha×kumo **0.29**（最も遠い）/ tebukuro×kumo 0.37 /
     alpha×gongitsune 0.57 / gongitsune×nezumi **0.91**（ほぼ同じ声・混ぜても無意味）
   - 遠いペア4つが実用候補。ただし女性×男性は中性的で不自然になりがち。**要試聴**
   - 進め方: npzに焼く前に Mac の Python Kokoro で WAV を作って試聴 → 採用分だけ v2 へ
3. **ファインチューン / 別モデル** — 日本語の学習データが1〜10時間しかないのがC帯の原因。
   伸びしろは最大だが工数も最大。別モデル候補(Qwen3-TTS/Chatterbox等)はライセンスの
   一次確認と 0.5B のiOS実行可能性が未検証

---

## ハーネス（2026-09-19 時点）

| | 結果 |
|---|---|
| Debug / Release ビルド | 両方 BUILD SUCCEEDED |
| `-only-testing:VoiceYourTextTests` | **414 tests / 0 failures**（セッション開始時 398） |
| SwiftLint（リポジトリルートから） | 0 serious |

テストは必ず `-only-testing:VoiceYourTextTests` を使うこと。
フルの `xcodebuild test` はUIテストが数百回ループして1時間超かかる。
