# オンデバイスTTS音質改善 調査レポート

- 作成日: 2026-09-14
- 対象: VoiceYourText (読み上げナレーター) iOS
- ゴール: クラウドTTSを最終的に完全撤去し、オンデバイスのみで読み上げ音質を上げる方式を決める
- 本レポートは**調査のみ**。コード変更・commit・push は一切していない。
- 調査範囲の基準コミット: `9488d00` (branch main)

---

## 0. 先に結論（要約）

1. **オンデバイスAI音声（Kokoro + MLX）はすでに実装・出荷されている。** 論点は「入れるかどうか」ではなく「なぜ日本語の音質が上がりきらないか」。
2. **日本語の音質が伸びない主因は、モデルではなくG2P（テキスト→音素変換）である可能性が高い。**
   - アプリの日本語G2Pは自作のかな→IPA変換表 (`JapaneseG2PProcessor.swift:47-135`)。**ピッチアクセント記号を一切出さない**。
   - 一方 Kokoro-82M の日本語音声は `misaki[ja]`（pyopenjtalk + full unidic、**アクセント記号あり**）の音素列で学習されている（[misaki README](https://github.com/hexgrad/misaki)）。つまり**学習時と違う音素列を食わせている**。
   - さらに現行実装は**数字・英字・未知記号を読み飛ばす**（`JapaneseG2PProcessor.swift:120-131`）。「2026年」「PDF」が無音になる。
3. **Apple標準の伸びしろが未回収。** ユーザーが設定画面で選んだ音声 (`SelectedVoiceIdentifier`) が**再生パスで一度も読まれていない**（詳細 §1.3）。Enhanced/Premium音声をダウンロードさせても現状は反映されない。
4. Kokoro日本語音声そのものの上限も低い：モデルカード上のグレードは **jf_alpha=C+ / jm_kumo=C-**、日本語の総学習データは **1〜10時間**（[VOICES.md](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)）。
5. → **推奨は C案（A案の即効改善 + KokoroのJA G2P差し替え）**。詳細は §4。

---

## 1. 現状把握：TTS実装の全リスト

### 1.1 全体像（3経路）

| 経路 | 実体 | 入口 |
|---|---|---|
| ① クラウドTTS | Google Cloud TTS (Wavenet / Neural2) を Cloud Run 経由で叩き、WAVをダウンロードして `AVAudioPlayer` で再生 | `TextInputView` の「クラウドTTS」選択時、PDFReaderの `useCloudTTS` |
| ② ローカルAI (Kokoro) | Kokoro-82M を MLX でオンデバイス推論 → WAV → `AVAudioPlayer` | `TextInputView` の「ローカルAI」選択 かつ モデルDL済み かつ 設定ON |
| ③ 端末TTS | `AVSpeechSynthesizer` | 上記いずれも不成立のときのフォールバック、およびミニプレイヤー/PDF/スキャン/オンボーディング |

### 1.2 クラウドTTS（撤去対象）の呼び出し箇所

**クライアント定義**
- `iOS/VoiceYourText/Dependencies/AudioAPIClient.swift:26-32` — `generateAudio` / `submitJob` / `getJobStatus` / `getVoices` の4API
- `iOS/VoiceYourText/Dependencies/AudioAPIClient.swift:80-83, 160-163, 192-195, 211-214` — `AUDIO_API_BASE_URL` を Info.plist から読む
- `iOS/VoiceYourText/Dependencies/AudioAPIClient.swift:94-97, 170-172, 201-203` — `CLOUDRUN_API_KEY` を `X-API-Key` ヘッダに付与
- `iOS/VoiceYourText/Dependencies/AudioAPIClient.swift:284-307` — `AudioAPIError`

**呼び出し側**
- `iOS/VoiceYourText/TextInputView.swift:43` — `@Dependency(\.audioAPI)`
- `iOS/VoiceYourText/TextInputView.swift:789` — `submitJob`（非同期ジョブ投入）
- `iOS/VoiceYourText/TextInputView.swift:815` — `getJobStatus`（10秒間隔・最大30回ポーリング、`TextInputView.swift:806-808`）
- `iOS/VoiceYourText/TextInputView.swift:902` — `getVoices`（音声一覧をサーバーから取得）
- `iOS/VoiceYourText/MyFilesView.swift:27, 305` — アプリ復帰時に未完了ジョブを再確認
- `iOS/VoiceYourText/Features/PDFReader/PDFReaderFeature.swift:75, 124` — `generateAudio`（同期API）
- `iOS/VoiceYourText/Features/PDFReader/SpeechSynthesizerClient.swift:33, 99` — `speakWithAPI`（`generateAudio` → DL → 再生）

**設定・鍵**
- `iOS/VoiceYourText/Info.plist:32-35` — `AUDIO_API_BASE_URL` / `CLOUDRUN_API_KEY`
- `iOS/VoiceYourText/config/Debug.xcconfig:17,20` / `config/Release.xcconfig:17,20` — 実値。
  - エンドポイント: `https://voiceyourtext-tts-990821915106.asia-northeast1.run.app`
  - **注意: APIキーの実値がリポジトリにコミットされている。** 撤去時にキー失効 + Cloud Run削除まで行うこと。

**付随するクライアント側の仕組み（クラウドTTS専用）**
- `iOS/VoiceYourText/Dependencies/AudioAPIClient.swift:34-48` — `TTSTimepoint`（`"index:start:end"` 形式のマーク名 → NSRange）
- `iOS/VoiceYourText/Features/Audio/AudioFileManager.swift:11-19, 36-60` — 生成音声のDL・ローカルキャッシュ・容量管理
- `iOS/VoiceYourText/Data/UserDefaultsManager.swift:160-179` — `pendingJobs`（ジョブID永続化）
- `iOS/VoiceYourText/Data/UserDefaultsManager.swift:75-81` — `CloudTTSVoiceId`
- `iOS/VoiceYourText/Data/SpeechTextRepository.swift:64-74, 146-172` — Core Data の `ttsMode` 列（`"cloud"` / `"basic"`）
- `iOS/VoiceYourText/TextInputView.swift:36-37, 126-128, 252-258, 719-725, 732, 769-780` — `useCloudTTS` / `cloudTTSAvailable` の状態とUI
- `iOS/VoiceYourText/TextInputView.swift:479-510` — timepoints による60fpsハイライトタイマー
- `iOS/VoiceYourText/TextInputView.swift:641-690` — `splitIntoChunksByBytes`（サーバー側バイト長制限対応。撤去後は不要）
- `iOS/VoiceYourText/Features/NowPlaying/NowPlayingFeature.swift:54, 284` — `setCloudTTSMode`

**サーバー側（本レポートのゴール上、最終的に全撤去対象）**
- `cloudrun/cmd/server/main.go:73-82` — `/getVoices` `/generateAudio` `/generateAudioWithTTS` `/jobs` `/jobs/process` `/jobs/{id}`
- `cloudrun/internal/handlers/generate_audio_tts.go:183-202` — SSML `<mark>` 挿入によるワード単位タイムポイント生成
- `cloudrun/internal/handlers/generate_audio_tts.go:237-263, 310-330` — Google Cloud TTS 呼び出し
- `cloudrun/internal/config/voice_config.go` — 全33音声定義（日本語は Wavenet A-D + **Neural2 B/C/D**、他に en/de/es/fr など）
- GCP: Cloud Run `voiceyourtext-tts` (asia-northeast1) / Cloud Tasks queue `tts-jobs` / GCS（署名URLで音声配布）
- ※ `functions/index.js:38` の `submitFeedback` はTTSと無関係。撤去対象外。

### 1.3 AVSpeechSynthesizer（端末TTS）使用箇所

- `iOS/VoiceYourText/Features/PDFReader/SpeechSynthesizerClient.swift:153-322` — 本体ラッパ（actor）。`speak` / `speakWithHighlight` / `stop` / `pause` / `fadeOutAndStop`
- `iOS/VoiceYourText/TextInputView.swift:551-601` — メインの端末TTS再生（4000文字チャンク分割つき）
- `iOS/VoiceYourText/SpeechView.swift:306-310, 346-350` — 一覧からの再生
- `iOS/VoiceYourText/SpeechView.swift:431-436` — Personal Voice 再生（`speechMyVoice`）
- `iOS/VoiceYourText/Features/NowPlaying/NowPlayingFeature.swift:191-197` — ミニプレイヤー
- `iOS/VoiceYourText/Features/PDFReader/PDFReaderFeature.swift:157-166` — PDF読み上げ（ローカルTTSモード）
- `iOS/VoiceYourText/Features/DocumentScanner/ScannedDocumentView.swift:220-236` — スキャン文書の読み上げ
- `iOS/VoiceYourText/Features/Onboarding/OnboardingView.swift:66-90` — オンボーディングのデモ再生
- `iOS/VoiceYourText/Features/Settings/Setting.swift:118-120` — 音声プレビュー（**ここだけ `identifier` を使っている**）
- `iOS/VoiceYourText/Features/Settings/VoiceSettingView.swift:102-111, 190-198` — 選択時プレビュー
- `iOS/VoiceYourText/Features/Player/SpeechSettings.swift:18, 30` — 速度表示の換算

> **🔴 重大な穴（A案の最初の一手）**
> 再生パス（`TextInputView.swift:571`、`PDFReaderFeature.swift:163`、`NowPlayingFeature.swift:197`、`SpeechView.swift:310, 350`、`ScannedDocumentView.swift:235`）はすべて
> `AVSpeechSynthesisVoice(language:)` を使っている。これは**その言語のデフォルト音声**を返す。
> ユーザーが `VoiceSettingView` で選んだ `SelectedVoiceIdentifier`（`UserDefaultsClient.swift:67-68`）を読んでいるのは
> **`Setting.swift:119` と `LanguageSettingView.swift:67` のプレビューだけ**。
> → ユーザーがEnhanced/Premium音声をダウンロードして選んでも、**実際の読み上げには反映されない**。

### 1.4 オンデバイスAI（Kokoro / MLX）実装

- `iOS/VoiceYourText/Features/KokoroTTS/KokoroTTSClient.swift:121-127` — TCA依存 `KokoroTTSClient`（`isAvailable` / `synthesize`）
- `iOS/VoiceYourText/Features/KokoroTTS/KokoroTTSClient.swift:26-117` — `KokoroVoice` 12種（英US4+英UK4+米男2、**日本語は `jf_alpha` / `jm_kumo` の2つだけ**）
- `iOS/VoiceYourText/Features/KokoroTTS/KokoroTTSClient.swift:193-348` — `KokoroEngine` actor。モデルキャッシュ・二重ロード防止・NPZ/NPYパース
- `iOS/VoiceYourText/Features/KokoroTTS/KokoroModelManager.swift:28-29` — モデル配布元
  `https://media.githubusercontent.com/media/mlalma/KokoroTestApp/main/Resources/kokoro-v1_0.safetensors` と `voices.npz`（**GitHub LFS CDN直リンク**）
- `iOS/VoiceYourText/Features/KokoroTTS/KokoroModelManager.swift:49-103` — チャンクDL（UI表記 約600MB / `KokoroTTSSectionView.swift:65`）
- `iOS/VoiceYourText/Features/KokoroTTS/KokoroTTSSectionView.swift:4-119` — 設定UI（DL/削除/ON-OFF/ボイス選択）
- `iOS/VoiceYourText/Features/KokoroTTS/KokoroTTSHelpers.swift:139-163` — `shouldUseKokoro` / `selectVoice` / 速度換算
- `iOS/VoiceYourText/TextInputView.swift:395-404, 517-548` — Kokoro分岐と再生、失敗時の端末TTSフォールバック
- `iOS/VoiceYourText/Features/PDFReader/SpeechSynthesizerClient.swift:39-62` — `speak` のみKokoro経路を持つ
- `iOS/VoiceYourText/Data/UserDefaultsManager.swift:181-190` — `KokoroEnabled` / `KokoroVoice`

**ベンダリングされた推論コード**（メインターゲットにインライン化済み。`KokoroTTSHelpers.swift:165-214` に理由と再発防止ガード）
- `Features/KokoroTTS/KokoroSwiftSources/` — Albert / Decoder / TTSEngine / TextProcessing など44ファイル
- `Features/KokoroTTS/MisakiSwiftSources/` — 英語G2P（BART fallback + 辞書）
- 同梱アセット（**アプリバイナリに載る**）: `us_bart.safetensors` 2.9MB, `gb_bart.safetensors` 2.9MB, `us_gold.json` 2.9MB, `us_silver.json` 3.0MB, `gb_gold.json` 2.7MB, `gb_silver.json` 3.5MB → **計 約17MB（すべて英語専用）**
- `iOS/LocalPackages/KokoroSwift/Package.swift` — `mlx-swift 0.30.6` / MisakiSwift(fork) / MLXUtilsLibrary 0.0.6、`platforms: .iOS(.v18)`
- プロジェクトの `IPHONEOS_DEPLOYMENT_TARGET = 18.0`

**🔴 日本語G2Pの実装（音質のボトルネック）**
- `Features/KokoroTTS/KokoroSwiftSources/TextProcessing/JapaneseG2PProcessor.swift:21-43` — `CFStringTokenizer` の Latin transcription 属性で漢字→ひらがな
- 同 `:47-135` — ひらがな→IPA の**手書き変換表**
  - ピッチアクセント記号なし
  - 促音「っ」を `ʔ` で近似（`:95`）
  - 長音「ー」を `ː` に一律変換（`:96`）
  - **表にない文字（数字・英字・多くの記号）は無条件に捨てる**（`:120-131`）
- 同 `:12-16` — `process` は `(ipa, nil)` を返す。**第2要素の `[MToken]?` が nil** → `KokoroTTS.generateAudio` (`TTSEngine/KokoroTTS.swift:170`) の戻り値もnil → `TimestampPredictor` が働かず、**日本語ではタイムスタンプが取れない**（英語はMisakiのMTokenがあるので取れる）

### 1.5 課金との紐付け

TTSエンジンの選択そのものは**課金でゲートされていない**。プレミアム判定が効くのは以下だけ：
- `iOS/VoiceYourText/TextInputView.swift:708-712` — 非課金は4,000文字超のテキストを保存不可（`SubscriptionView(source: "text_char_limit")` へ誘導、`:203-213`）
- `iOS/VoiceYourText/TextInputView.swift:305-308` — 非課金はプレイヤー画面にAdMobバナー
- `iOS/VoiceYourText/Features/Settings/PurchaseManager.swift:133-179` — RevenueCat由来のプレミアム状態

→ **クラウドTTS撤去は課金導線を直接壊さない。** ただしクラウドTTSは事実上の「高音質＝有料っぽい価値」を担っているので、撤去するならその価値をオンデバイス側で代替する必要がある（マーケ上の論点であって技術的依存ではない）。

### 1.6 その他のサーバー依存（TTS以外・撤去対象外）

参考までに。TTS撤去とは独立。
- `Dependencies/FeedbackClient.swift:13` — Firebase Functions `submitFeedback`
- `Dependencies/GoogleDriveClient.swift:91-125` — Google Drive API
- `Dependencies/AozoraClient.swift:67-92` — 青空文庫
- `Dependencies/WebPageFetchClient.swift:22` — リンク取り込み
- `Features/Settings/SubscriptionView.swift:22-23` — 規約/プライバシーURL
- Firebase Analytics / Crashlytics / RevenueCat / AdMob

---

## 2. クラウドTTSを完全撤去したときに壊れる箇所・失われる機能

| # | 失われるもの | 影響箇所 | 代替可能性 |
|---|---|---|---|
| 1 | **Wavenet / Neural2 の日本語音質**（`voice_config.go` の ja-JP-Neural2-B/C/D） | 「クラウドTTS」選択時の全再生 | オンデバイスで同等は困難。Kokoro日本語はモデルカード上 C〜C+。**実質的なダウングレードになる可能性が高く、これが最大の意思決定ポイント** |
| 2 | **ワード単位のタイムポイント → テキストハイライト同期** | `TextInputView.swift:479-510`、`AudioAPIClient.swift:34-48` | 端末TTSは `willSpeakRange` で代替可（`SpeechSynthesizerClient.swift:343-357`）。**Kokoro日本語は現状タイムスタンプが取れない**（§1.4）。Kokoro英語は `TimestampPredictor` で可能 |
| 3 | **33音声の選択肢**（日本語7、他9言語） | `getVoices` → `VoicePickerSheet`（`TextInputView.swift:902, 938-`） | Kokoroは日本語2・英語10のみ。**日本語以外の8言語は端末TTS一択になる** |
| 4 | **生成済み音声の永続保存・再生**（保存したファイルは何度でも同じ音声で再生） | `AudioFileManager`、`ttsMode="cloud"` の既存レコード | Kokoroは毎回オンデバイス生成（＝毎回レイテンシ）。生成WAVをキャッシュする仕組みは要新規実装 |
| 5 | **既存ユーザーのデータ移行** | Core Data `ttsMode="cloud"` のレコード、`Documents/audio/` の既存WAV、`pendingJobs` | 撤去時に `ttsMode` の読み替え（cloud→basic）とpendingJob掃除が必要。既存WAVは残して再生だけ許す手もある |
| 6 | 非同期ジョブUI（「高音質音声を生成中...」バナー、進捗） | `TextInputView.swift:276-289, 806-878`、`MyFilesView.swift:299-310` | 不要になる。削除対象 |
| 7 | バイト数ベースのチャンク分割 | `TextInputView.swift:641-690` | サーバー制限対応なので不要。削除対象 |

**撤去時に必ずやること**
- `CLOUDRUN_API_KEY` の失効（リポジトリに平文コミット済み）
- Cloud Run `voiceyourtext-tts` / Cloud Tasks `tts-jobs` / GCS バケットの削除（コスト停止）
- Info.plist / xcconfig の該当キー削除
- `ttsMode` マイグレーション

---

## 3. オンデバイス案（3案）

### A案: Apple標準を使い切る

やること:
1. **`SelectedVoiceIdentifier` を全再生パスで使う**（§1.3 の穴を塞ぐ）。`AVSpeechSynthesisVoice(identifier:)` にフォールバック付きで置換。対象6ファイル。
2. **Enhanced / Premium 音声のダウンロード誘導を強化**。現状 `VoiceSettingView.swift:33-54` に導線はあるが、DL済み音声が無いときだけ出る静的な案内。再生画面からも誘導し、`quality` バッジ（`VoiceSettingView.swift:231-253`）を実際に効かせる。
   - ※ アプリから直接DLする公式APIは無い。ユーザーが 設定 > アクセシビリティ > 読み上げコンテンツ > 声 で落とす必要がある。
3. **Personal Voice の再生経路を整備**。現状 `SpeechView.swift:431-436` は独立した関数で、通常再生パスに繋がっていない。`VoiceSettingView.swift:71` で英語のときだけ出る（Apple側が英語のみ対応のため）。
4. **読み辞書と韻律チューニング**。既存 `UserDictionary` は `SpeechSynthesizerClient.swift:64-73` で `speak` にしか適用されず、**`speakWithHighlight`（＝メインの再生経路）では適用されていない**（`:84-86` にコメントあり）。ここを直すと固有名詞の誤読が減る。数字・単位・英略語の前処理、`AVSpeechUtterance` の `preUtteranceDelay` / 句読点での間、SSML相当の整形。

- 日本語音質: Kyoko / O-ren / Hattori の Enhanced（Premium の日本語での提供有無は**要実機確認**）。Neural2 ほどではないが、現状のデフォルト品質よりは明確に上。
- 完全オフライン: 音声DL後は完全オフライン。DL自体はOS機能でありアプリのサーバーではない。
- リスク: 音質の上限がAppleに依存。ユーザーに「設定アプリで音声を落とす」という手間を要求する。

### B案: ニューラルTTSモデルを内蔵（＝現行Kokoroの強化 or 差し替え）

**現状は「B案がすでに部分的に動いている」状態。** 選択肢を一次情報で確認した結果：

| モデル | ライセンス（一次情報） | 日本語 | 判定 |
|---|---|---|---|
| **Kokoro-82M** | Apache-2.0（[モデルカード](https://huggingface.co/hexgrad/Kokoro-82M)） | あり。jf_alpha(C+) / jf_gongitsune(C) / jf_nezumi(C-) / jf_tebukuro(C) / jm_kumo(C-)。**日本語総学習データ 1〜10時間**（[VOICES.md](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)） | **採用中**。商用OK。音質上限は低め |
| **misaki (G2P)** | Apache-2.0（[README](https://github.com/hexgrad/misaki)） | `misaki[ja]` は **pyopenjtalk + full unidic** を使い「pitch accent marks」を出力 | 日本語音質の鍵。ただしPython実装。Swift移植が必要 |
| **pyopenjtalk** | MIT。同梱 Open JTalk / hts_engine_API は Modified BSD（[README](https://github.com/r9y9/pyopenjtalk)） | 日本語専用 | **商用利用可**。C/C++実装なのでiOS組み込み自体は現実的。※同梱htsvoice・辞書の個別ライセンスは別途要確認 |
| **Style-Bert-VITS2** | **AGPL-3.0 / LGPL-3.0 デュアル**（[リポジトリ](https://github.com/litagin02/Style-Bert-VITS2)） | 強い（JP-Extra あり） | **❌ 不可**。AGPLはクローズドソースのApp Storeアプリと両立しない |
| **Piper** | **GPL-3.0**（[piper1-gpl](https://github.com/OHF-Voice/piper1-gpl)） | **日本語音声なし**（[VOICES.md](https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md) の43言語に ja は不在） | **❌ 不可**（ライセンス・日本語とも） |
| **VITS (原典)** | 要確認（jaywalnut310/vits は MIT との情報があるが**本調査では一次確認できていない**） | 日本語学習済み公開チェックポイントは多くが個別ライセンス | **未確認**。自前学習前提になり工数が跳ねる |
| **VOICEVOX CORE** | コードは MIT（[リポジトリ](https://github.com/VOICEVOX/voicevox_core)、0.16以降） | 日本語専用・音質高い | **要精査**。音声ライブラリはキャラごとに別規約で、生成物に「VOICEVOX:キャラ名」のクレジット表記が必要（[VOICEVOX Q&A](https://voicevox.hiroshiba.jp/qa/) / [ソフトウェア利用規約](https://voicevox.hiroshiba.jp/term/)）。読み上げアプリの出力すべてにクレジットを要求する運用は現実的でなく、キャラごとの禁止事項もある。**iOSビルドの可否も本調査では未確認** |

**Core ML化について**: Kokoroを Core ML に変換すれば MLX 依存（および約17MBの英語アセット・600MBモデル）の扱いが変わる可能性があるが、**変換パイプラインの実在・精度劣化・速度は本調査では未確認**。現行はMLXで動いている以上、Core ML化は音質改善ではなく最適化の話であり、今回のゴールとは別軸。

- アプリサイズ増: Kokoro維持なら**バイナリ +約17MB**（英語アセット）、モデルは初回DL 約600MB（アプリ外）。
- 完全オフライン: **推論はオフライン。ただし初回のモデルDLはネットワーク必須**（§4の要確認事項）。
- リスク: 日本語のグレードC帯という天井。速度・初回レイテンシは**実測が必要（未計測）**。

### C案: 折衷 — A案の即効改善 + Kokoro日本語G2Pの差し替え

1. **A案の1〜4を全部やる**（端末TTSのベースラインを上げる。Kokoro未DLユーザー・日本語以外8言語・ミニプレイヤー/PDF/スキャンはすべてここが効く）
2. **Kokoro日本語G2Pを `misaki[ja]` 相当に差し替える**（pyopenjtalk をiOSに組み込み、ピッチアクセント付き音素列を生成）
3. Kokoro生成WAVをファイル単位でキャッシュし、2回目以降のレイテンシをゼロにする（クラウドTTSの「保存された音声」体験を代替）
4. モデル配布は現状どおりオンデマンドDL

**「CDN配布はサーバーを使わない要件に反しないか」** — 要確認事項として明示しておく。
- 現状すでに `media.githubusercontent.com`（GitHub LFS CDN）から600MBを落としている（`KokoroModelManager.swift:28-29`）。**自前サーバーではないが、外部ホストへの依存ではある**。
- 「サーバーを使わない」の意図が (a) 運用コストゼロ なら現状で満たす、(b) 通信ゼロ なら満たさない。
- (b) が要件なら選択肢は「モデルをアプリにバンドル（+600MB。App Store の 4GB 上限には収まるが、Cellular DL制限やレビュー観点で現実的でない）」か「A案のみ」。
- **さらにリスク**: 他人のリポジトリ（`mlalma/KokoroTestApp`）のLFSを本番アプリが直参照している。消されたら全ユーザーがモデルを落とせなくなる。撤去うんぬん以前に、**自前のホスティングへ移すべき**。

---

## 4. 比較表

| 観点 | A案: Apple標準 | B案: ニューラルTTS内蔵 | C案: 折衷（推奨） |
|---|---|---|---|
| **日本語音質** | 中。Kyoko/O-ren Enhanced。Neural2には届かないが現行デフォルトより明確に上。自然さは安定（Apple製） | 中〜未知。Kokoro ja のモデルカード grade は **C+ / C-**、学習1〜10h。**G2Pを直さない限り現行と変わらない**（アクセント欠落・数字読み飛ばし） | **A案の底上げ + Kokoroのアクセント修正**。両輪。最も上振れが期待できる |
| **アプリサイズ増** | **±0**（音声はOS側、ユーザーがDL） | +約17MB（英語アセット）／モデル約600MBは端末DL。Kokoro撤去なら **−17MB** | +約17MB（現状維持）＋G2P辞書分（unidic系は数十MB〜。**要計測**） |
| **商用ライセンス** | **問題なし**（OS標準） | Kokoro Apache-2.0 ✅ / misaki Apache-2.0 ✅ / pyopenjtalk MIT + Modified BSD ✅。Style-Bert-VITS2 AGPL ❌、Piper GPL+日本語なし ❌、VOICEVOX はクレジット表記必須で要精査 | **問題なし**（Apache-2.0 + MIT/BSD の範囲に収まる） |
| **実装工数（人日）** | **3〜5人日**。①voiceIdentifier配線 1〜2日 ②DL誘導UI 1日 ③Personal Voice配線 0.5日 ④辞書をspeakWithHighlightに適用+前処理 1〜1.5日 | **8〜20人日**。pyopenjtalk相当のiOS組み込み（C/C++ブリッジ + 辞書バンドル）5〜10日、音素列の互換検証 3〜5日、キャッシュ 2日、不確実性大 | **12〜25人日**（A案 + B案。ただしA案は先に単独リリース可能） |
| **必要OSバージョン / 対応端末** | iOS 17+（Personal Voice）。Enhanced/Premium は iOS 16+。**現行ターゲット iOS 18.0 で全て満たす** | **iOS 18.0**（`LocalPackages/KokoroSwift/Package.swift`）。MLX = Metal必須。実機のみ（シミュレータはmlx-swift 0.30.6で動作するようになった） | iOS 18.0 |
| **完全オフライン可否** | **◎**（音声DL後は完全オフライン。DLはOS機能） | **△**（推論はオフラインだが初回600MBのモデルDLに外部CDNが必要） | **△**（同上。A案部分のみなら◎） |
| **リスク** | 音質上限がAppleに依存。ユーザーに設定アプリでの操作を要求 | ①日本語グレードがC帯という天井 ②推論速度・初回レイテンシ**未計測** ③モデル配布元が他人のリポジトリ ④pyopenjtalk組み込みが想定より重い可能性 | A案部分はリスク小・即効。B案部分のリスクはB案と同じだが、**A案が先に出ているので失敗しても退路がある** |

> 表中「未計測 / 要確認」と書いた項目は、本調査で一次情報にあたれなかったものです。推測値は入れていません。

---

## 5. 推奨案とPoC手順

### 推奨: **C案（A案を先行リリース → KokoroのJA G2P差し替えをPoCで判断）**

理由:
1. A案の①（`SelectedVoiceIdentifier` を再生パスで使う）は**バグ修正に近く、数人日で全ユーザーに効く**。Kokoro未DLユーザー・日本語以外の8言語・ミニプレイヤー/PDF/スキャン/オンボーディングはすべて端末TTSなので、効果範囲が最も広い。
2. 日本語でKokoroが期待ほど良くない理由が**モデルではなくG2Pである可能性が高い**ので、モデルを乗り換える前にそこを検証すべき。乗り換え候補（Style-Bert-VITS2 / Piper）はライセンスまたは日本語非対応で**そもそも使えない**。
3. クラウドTTS（Neural2）を捨てると日本語音質は一度下がる。A案でベースラインを上げておかないと、撤去がそのまま体験の劣化になる。

### PoC手順

**Phase 0 — 現状の音を録る（0.5人日）** ※ここまでで「何が悪いか」がほぼ判明する

1. 評価用テキストを5本固定する。必ず含める: 漢字熟語、固有名詞、**アラビア数字（「2026年3月15日」）**、**英略語（「PDF」「iOS」）**、アクセントで意味が変わる語（「橋／箸」「雨／飴」）、長文（1,000字）。
2. 同じテキストで4通りを録音・並べて聴く:
   - ① 現行クラウドTTS（ja-JP-Neural2-B）
   - ② 現行Kokoro `jf_alpha`
   - ③ 端末TTS デフォルト（＝いまユーザーが聞いている音）
   - ④ 端末TTS + Kyoko Enhanced（`AVSpeechSynthesisVoice(identifier:)` 明示）
3. **同時に、実機で `AVSpeechSynthesisVoice.speechVoices()` を全ダンプ**し、ja-JP に `.enhanced` / `.premium` が実在するか確認する（§3 A案の未確認事項を潰す）。
4. **同時に、Kokoroの実測を取る**: 1,000字あたりの初回レイテンシ（モデルロード込み）と2回目以降、ピークメモリ。`KokoroTTSClient.liveValue.synthesize` の前後で計測するだけ。

**判定**: ②が③④より明確に悪い／数字と英略語が消えている → G2Pが原因確定。Phase 2へ。
②が④と同等以下で、かつ数字も読める → Kokoroの日本語はモデル自体が上限。**Kokoro日本語は諦めてA案に集中**という判断もありうる。

**Phase 1 — A案の最小実装（1人日）**

- `TextInputView.swift:571` の1行を `AVSpeechSynthesisVoice(identifier:)` 優先＋`language:`フォールバックに変える。
- デバッグメニューから「保存済みidentifierで読む／言語デフォルトで読む」を切り替えられるようにして、Phase 0 の③と④を**同じアプリ内で**比較する。
- ここで差が体感できれば、残り5ファイルへの展開と辞書/前処理は確定で進めてよい。

**Phase 2 — 日本語G2Pの検証（2〜3人日、コードを書く前に机上でやる）**

音質を判断するのに**iOSへのpyopenjtalk組み込みは不要**。段階を分ける:

1. **Mac上のPythonで** `misaki[ja]` に Phase 0 のテキストを通し、音素列を出す。
2. 同じテキストをアプリの `JapaneseG2PProcessor` に通した音素列と**文字列diffする**（`process(input:)` は純粋関数なのでユニットテストから直接呼べる。`VoiceYourTextTests/` に足すだけ）。
3. **Mac上のPythonのKokoro**で、①misaki音素列 ②アプリの音素列 の両方を `jf_alpha` に食わせてWAVを2本作り、聴き比べる。
   - ここで①が明確に良ければ、**「pyopenjtalkをiOSに組み込む工数を払う価値がある」と確定できる**。良くならなければB案部分は中止し、A案＋クラウド撤去のみで着地する。

**Phase 3 — 以降（判断後）**

- pyopenjtalk の iOS 組み込み（C/C++ + 辞書バンドル。辞書サイズを必ず実測してアプリサイズ影響を確定させる）
- Kokoro生成WAVのファイル単位キャッシュ
- モデル配布元を `mlalma/KokoroTestApp` から自前ホストへ移す（**クラウド撤去とは独立に、今すぐやるべきリスク低減**）
- クラウドTTS撤去（§2の7項目 + キー失効 + GCPリソース削除 + `ttsMode` マイグレーション）
  - **2026-09-15: アプリ側のコード撤去は完了**（[cloud-tts-removal-2026-09-15.md](cloud-tts-removal-2026-09-15.md)）。
    **`CLOUDRUN_API_KEY` の失効・GCPリソース削除・`cloudrun/` の削除は未実施**（出荷済み v1.2.0 ユーザーが使用中のため、新バージョン公開後に実施）。

---

## 6. 未確認事項（推測を避けた箇所）

| 項目 | 状態 |
|---|---|
| ja-JP に `.premium` 品質の音声が実在するか | **未確認**。Phase 0-3 の実機ダンプで確定させる |
| Kokoro の実機推論速度・初回レイテンシ・ピークメモリ | **未計測**。Phase 0-4 |
| VITS (jaywalnut310/vits) のライセンス | **一次確認できていない**。MITとの二次情報はあるが LICENSE 未確認 |
| VOICEVOX CORE の iOS ビルド可否、音声ライブラリの個別規約 | **未確認**。クレジット表記必須という点だけ一次情報で確認済み |
| Kokoro の Core ML 変換パイプラインの実在・精度・速度 | **未確認** |
| pyopenjtalk 同梱 htsvoice / 辞書の個別ライセンスと容量 | **未確認**（README が別READMEを参照している） |
| 「サーバーを使わない」にモデルのCDN配布が含まれるか | **要合意**（§3 C案） |

---

## 参考リンク（一次情報）

- Kokoro-82M モデルカード（Apache-2.0）: https://huggingface.co/hexgrad/Kokoro-82M
- Kokoro VOICES.md（日本語音声のグレード・学習時間）: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md
- misaki（Apache-2.0、日本語はpyopenjtalk+full unidicでpitch accent対応）: https://github.com/hexgrad/misaki
- pyopenjtalk（MIT、Open JTalk/hts_engine は Modified BSD）: https://github.com/r9y9/pyopenjtalk
- Style-Bert-VITS2（AGPL-3.0 / LGPL-3.0）: https://github.com/litagin02/Style-Bert-VITS2
- Piper（GPL-3.0）: https://github.com/OHF-Voice/piper1-gpl
- Piper 対応音声一覧（日本語なし）: https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md
- VOICEVOX CORE（コードはMIT、0.16以降）: https://github.com/VOICEVOX/voicevox_core
- VOICEVOX ソフトウェア利用規約: https://voicevox.hiroshiba.jp/term/
- VOICEVOX Q&A（クレジット表記）: https://voicevox.hiroshiba.jp/qa/
- AVSpeechSynthesisVoiceQuality.premium: https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoicequality/premium
