# Android 音声品質改善（2026-10-29）

## 通常版：高品質な端末内音声の自動選択

`VoiceOptions.resolve` を追加し、`TtsViewModel.applyLanguage` から呼び出す。

- 保存済みで利用可能な声を最優先する。ユーザーが選んだネットワーク音声や低い品質値の声も維持する。
- 自動選択では、インストール済み・オフライン・既定の声と同じロケールの候補を品質値の高い順で選ぶ。同品質なら既定の声を維持する。
- 英語などの地域差を自動で変更しない。候補がなければ既定の声を維持する。
- 保存済みの声が削除済み・未インストール・別言語なら自動選択へ戻る。
- 自動選択結果は明示的な選択として保存しない。画面の「標準」を保ち、13言語で説明を更新した。
- `setVoice` の成功を確認してから選択状態を反映する。

品質値はTTSエンジンが申告する値で、人による自然さの評価ではない。追加のクラウド音声APIは導入していない。

参考: [Android Voice API](https://developer.android.com/reference/android/speech/tts/Voice)、[TextToSpeech.setVoice](https://developer.android.com/reference/android/speech/tts/TextToSpeech#setVoice(android.speech.tts.Voice))

## Kokoro：Debug試作画面の改善

AndroidのKokoroは既存のDebug専用ONNX試作で、通常の読み上げ画面・Releaseには未統合。今回もこの構成を保つ。

- 全文をG2Pで変換した後、文末を優先して分割。空白・句読点・閉じ括弧を含め、元の音素列を欠落なく維持する。
- 短文をまとめ、最後の断片が極端に短くならないように分割する。
- 2026-10-20のメモリ計測を踏まえて最大120音素を維持。iOSの200音素をそのまま採用していない。
- 「合成を停止」ボタン、画面のonStopから合成Jobをキャンセル。現在のネイティブ推論が終わった後、次のチャンクへ進まず終了する。
- 完成前のWAVは一意な一時ファイルに保存し、キャンセル時に削除する。完成済みのWAVを途中結果で上書きしない。
- 既存の選択音声・速度を使用し、無音・ピッチ・音量の補正は本番の合成処理に追加していない。

Kokoroの音声合成は端末内で行うため、今回の変更に伴うクラウド合成の従量課金は発生しない。モデル配信の費用や端末の処理負荷は別。モデル本番導入前の判断事項は [kokoro-prototype.md](kokoro-prototype.md) を参照。

## 検証結果

JDK 17 / Gradle 8.13 / Pixel_6_API_33エミュレータ。

- `:app:assembleDebug` 成功。
- `:app:testDebugUnitTest` 全172件成功、失敗・エラー・スキップ0。
- `:app:lintDebug` 成功、エラー0・警告16（baselineで除外されたものを除く）。
- `:app:assembleDebugAndroidTest` 成功。
- 実モデルのinstrumentationテスト3件成功。短文・長文・比較文の生成、キャンセル時の完成済み音声保全、一時ファイル削除、画面の停止ボタンを確認した。
- 合計175件。`git diff --check` と全Android文字列XMLの構文確認も成功。
- 通常版の音声自動選択は純粋な選択ロジックの回帰テストで確認。端末ごとのTTSエンジンの音質は実機での試聴が必要。

実行例（android/から）:

```sh
JAVA_HOME=/Users/entaku/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home ./gradlew --offline :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:assembleDebugAndroidTest
adb -s emulator-5554 shell am instrument -w -e kokoroModelTest true -e package com.entaku.VoiceYourText.kokoro com.entaku.VoiceYourText.test/androidx.test.runner.AndroidJUnitRunner
```

ログ: `/tmp/narrator-android-20261029/{gradle.log,ui-test-build.log,final-lint.log,instrumentation.log}`

Debug APK: `android/app/build/outputs/apk/debug/app-debug.apk`（モデルファイルは別途配置が必要）。配信・本番デプロイは未実施。

## 実際の生成音声

既存の固定リビジョンモデルについてチェックサムを再検証し、ローカルに保存済みのファイルを使用した。新規クラウド音声API呼び出しはない。

| 入力 | 合成時間 | 音声長 | チャンク数 |
| --- | ---: | ---: | ---: |
| 短文28字 | 4.091秒 | 5.05秒 | 1 |
| 長文336字 | 45.085秒 | 58.3秒 | 6 |
| 比較文167字 | 21.598秒 | 28.275秒 | 5 |

モデル初期化は別途1.665秒。これは今回1回のエミュレータ計測で、物理端末の性能・発熱・メモリ・自然さは未評価。

試聴音声は今回のAndroidアプリで実際にONNX合成した `jf_alpha`、speed 1.0、24kHzモノラル。比較用ファイルのみ一定ゲインで−22 LUFSへ調整（−1.71 dB、ピーク−6.40 dBTP）。速度やピッチは変更していない。

保存先:
`/Users/entaku/.codex/visualizations/2026/10/27/01a17adb-fe8b-76a3-93d5-c0726533a078/android-voice-update-2026-10-29/`

- `android-kokoro-preview.wav`
- `preview-manifest.json`
- `metrics.txt`
