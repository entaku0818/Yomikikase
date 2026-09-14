# クラウドTTS撤去 作業記録

- 実施日: 2026-09-15
- 対象: VoiceYourText (読み上げナレーター) iOS
- 基準: [`tts-ondevice-research-2026-09-14.md`](tts-ondevice-research-2026-09-14.md) §1.2 / §2
- 範囲: **アプリのコードからのクラウドTTS撤去のみ**。GCPリソース・APIキー・`cloudrun/` は未着手（下記「公開後に残っている作業」）

---

## 🔴 公開後に残っている作業（未実施・要対応）

出荷済み v1.2.0 のユーザーがまだこのサーバーで読み上げているため、**本バージョン公開後に**実施する。

1. **`CLOUDRUN_API_KEY` の失効**
   `893d923d1fa0bd0773a6d1130d906aafdc63bf28abbd3ea207580a5318a257c4`
   - 今回 `config/Debug.xcconfig` / `config/Release.xcconfig` / `Info.plist` から削除したが、**失効はされていない**。
   - リポジトリの**コミット履歴には平文で残っている**ため、削除だけでは無効化にならない。必ずサーバー側で失効させること。
2. **GCPリソースの削除**（プロジェクト `voiceyourtext`）
   - Cloud Run `voiceyourtext-tts` (asia-northeast1)
   - Cloud Tasks queue `tts-jobs` (asia-northeast1)
   - 音声配布に使っていた GCS バケット
3. **`cloudrun/` ディレクトリの削除**
   - 上記リソースが生きている間はデプロイ元なので残してある。リソース削除と同時に消す。

---

## 消したもの

### 削除したファイル
| ファイル | 内容 |
|---|---|
| `Dependencies/AudioAPIClient.swift` | `generateAudio` / `submitJob` / `getJobStatus` / `getVoices` の4API、`TTSTimepoint`、`AudioResponse`、`VoiceConfig`、`AudioAPIError` |
| `LanguageVoiceMapper.swift` | 言語コード → Cloud Run ボイスID / ロケール変換（クラウド専用だったため全体が不要に） |
| `VoiceYourTextTests/LanguageVoiceMapperTests.swift` | 上記のテスト14件 |

### 変更したファイル
| ファイル | 消したもの |
|---|---|
| `TextInputView.swift` | `@Dependency(\.audioAPI)`、ジョブ投入・10秒×30回ポーリング、「高音質音声を生成中...」バナー、timepoints による60fpsハイライトタイマー、`splitIntoChunksByBytes`、`useCloudTTS` / `cloudTTSAvailable`、音声エンジン選択Picker、`VoicePickerSheet` / `VoiceRow` |
| `MyFilesView.swift` | アプリ復帰時の未完了ジョブ再確認 (`checkPendingJobs`)、`TTSJobCompleted` 通知購読、一覧の「生成中」スピナー (`FileItem.isProcessing`) |
| `Features/PDFReader/PDFReaderFeature.swift` | `generateAudio` 経路、`useCloudTTS` / `cloudTTSVoiceId` / `isGeneratingAudio`、`toggleCloudTTS` ほか4アクション、ヘッダーの Cloud/Local トグル、「音声を生成中...」表示 |
| `Features/PDFReader/SpeechSynthesizerClient.swift` | `speakWithAPI`、actor の `playAudioFromURL` |
| `Features/NowPlaying/NowPlayingFeature.swift` | `setCloudTTSMode` / `startPlayingWithCloudTTS`、`useCloudTTS` / `cloudTTSAudioURL` / `isGeneratingAudio`、`resumePlaying` のクラウド再生分岐 |
| `SpeechView.swift` | 未使用だった `speakWithAPI(text:viewStore:)` |
| `Features/Player/TTSInfoSheet.swift` | 「高音質TTS」表示・クラウド音声情報。端末TTS / 保存済み音声の2状態に再構成 |
| `Features/Audio/AudioFileManager.swift` | `downloadAudio`（新規DLが無くなったため）と `AudioFileError` |
| `data/UserDefaultsManager.swift` | `pendingJobs` / `setPendingJob` / `clearPendingJob` / `pendingJobId`、`cloudTTSVoiceId` |
| `data/UserDefaultsClient.swift` | 同上（live / testValue 両方） |
| `Info.plist`, `config/Debug.xcconfig`, `config/Release.xcconfig` | `AUDIO_API_BASE_URL` / `CLOUDRUN_API_KEY`（`.sample` には元から無し） |

### 追加したファイル
| ファイル | 内容 |
|---|---|
| `data/CloudTTSCleanup.swift` | 起動時に `PendingTTSJobs` / `CloudTTSVoiceId` を静かに削除する後片付け |
| `VoiceYourTextTests/CloudTTSCleanupTests.swift` | 上記のテスト4件 |

---

## 既存ユーザーに起きること

| | 挙動 |
|---|---|
| **生成済みの音声ファイル** | **消さない。そのまま再生できる。** `ttsMode == "cloud"` かつ `Documents/audio/` にファイルがあるレコードは、これまで通りその音声ファイルで再生する（`TextInputView.playGeneratedAudio`）。ユーザーが作った資産を奪わないため |
| 保存済み音声のハイライト | **無くなる**。ワード単位のタイムポイントはサーバー生成だったため。音声再生自体は影響なし |
| 未完了ジョブ（`pendingJobs`） | 起動時に静かに削除。もう完了しようがなく、放置すると「生成中」バナーが永久に残るため。ユーザーへの通知・ダイアログは無し |
| クラウドTTSを選んでいた設定 | 端末TTSに寄せる。編集して保存し直すと `ttsMode` は `"basic"` に更新され、以後は端末TTSで読む（古い音声ファイルが編集後のテキストと食い違う事故を防ぐ） |
| クラウド音声の選択 (`CloudTTSVoiceId`) | 起動時に削除。選べる音声が無くなったため |
| 新規テキストの読み上げ | Kokoro（モデルDL済み・有効時）→ 端末TTS(`AVSpeechSynthesizer`) のフォールバック。以前と同じ経路 |
| PDF読み上げ | 端末TTSのみ（Cloud/Local トグルは消滅） |
| 課金導線 | 変化なし（TTSエンジン選択は元々課金でゲートされていない） |

### ハイライトについて
クラウド経由の timepoints ハイライトを消した後も、`willSpeakRange` ベースのハイライトは全経路で従来どおり動く：
`TextInputView.playWithDeviceTTS` / `SpeechView.speakWithHighlight` / `PDFReaderFeature.startReading` いずれも
`SpeechSynthesizerClient.speakWithHighlight`（ユーザー辞書の逆引き対応込み）を通る。Kokoro と保存済み音声は
元々 `AVAudioPlayer` 再生でハイライト非対応（変更なし）。

---

## 検証結果

| ハーネス | 結果 |
|---|---|
| Debug ビルド | ✅ BUILD SUCCEEDED |
| Release ビルド | ✅ BUILD SUCCEEDED |
| `-only-testing:VoiceYourTextTests` | ✅ 382 tests / 0 failures（撤去前 398。削除したコードのテスト -20、`CloudTTSCleanup` のテスト +4） |
| SwiftLint（リポジトリルートから実行） | ✅ 0 serious（warning 725 / 撤去前 766） |
