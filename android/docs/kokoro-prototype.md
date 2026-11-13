# Kokoro日本語・Android試作

Debug専用の独立画面で、入力した日本語から端末内でWAVを生成して試聴する。
通常の読み上げ画面・Release版には組み込んでいない。

## 構成

- ONNX Runtime Android 1.22.0、CPU 2スレッド。
- Kokoro v1.0の8-bit ONNXモデルと日本語音声 `jf_alpha`。
- Kuromoji IPADIC 0.9.0で漢字の読みを取得し、iOSのかな→IPA表で音素化。
- 1チャンク最大120音素、可能な限り文境界で分割。モデル上限510まで詰めずメモリを抑える。
- 24kHz・16bit・モノラルWAVを逐次書き出す。キャンセル／失敗時は不完全な出力を削除。
- 2000文字まで。数字は各桁を読み、未知の漢字・絵文字等はエラーにする。音素を黙って落とさない。
- AndroidでのMisaki相当のアクセント・助数詞・英単語読みは未実装。iOSとの音質同等性は未確認。

## 再現手順

リポジトリルートで実行する。JDK 17とAndroid SDKのadbが必要。

```sh
python3 android/scripts/prepare_kokoro.py
cd android
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
cd ..
adb -s emulator-5554 install -r android/app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5554 install -r android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s emulator-5554 shell run-as com.entaku.VoiceYourText mkdir -p files/kokoro
COPYFILE_DISABLE=1 tar -C android/build/kokoro -cf - model.onnx voice.bin tokenizer.json | adb -s emulator-5554 shell run-as com.entaku.VoiceYourText tar -xf - -C files/kokoro
adb -s emulator-5554 shell am start -n com.entaku.VoiceYourText/.kokoro.KokoroPrototypeActivity
```

`emulator-5554`は対象端末のシリアルに置き換える。端末内ファイルはアプリ削除で消える。
取得スクリプトはリビジョン固定・チェックサム検証付き。約93MBをgit管理外の `android/build/kokoro/` に保存する。

モデルが必要な計測テストは通常のCIではスキップする。配置後に明示的に実行する。

```sh
adb -s emulator-5554 shell am instrument -w -e kokoroModelTest true -e class com.entaku.VoiceYourText.kokoro.KokoroPrototypeTest com.entaku.VoiceYourText.test/androidx.test.runner.AndroidJUnitRunner
adb -s emulator-5554 exec-out run-as com.entaku.VoiceYourText cat files/kokoro/metrics.txt
adb -s emulator-5554 exec-out run-as com.entaku.VoiceYourText cat files/kokoro/short.wav > android/build/kokoro/short.wav
adb -s emulator-5554 exec-out run-as com.entaku.VoiceYourText cat files/kokoro/long.wav > android/build/kokoro/long.wav
```

## 2026-10-20の計測結果

Pixel_6_API_33エミュレーター、CPU 2スレッド。実機／主観音質の確認ではない。

| 入力 | 合成時間 | 生成音声 | チャンク | RTF |
|---|---:|---:|---:|---:|
| 28文字 | 3.786秒 | 5.05秒 | 1 | 0.750 |
| 336文字 | 43.625秒 | 58.3秒 | 6 | 0.748 |

- 初期化時間: 1.155秒（合成時間とは別）。
- アプリ全体のPSSを2秒間隔で観測した最大値: 647,332 KiB（約632 MiB）。瞬間的な最大値は保証しない。
- 当初の500音素分割では長文が2チャンク、合成41.503秒／音声53.925秒。途中のPSS観測で約1.03 GiBに達したため120音素に縮小した。分割によって韻律や生成音声長も変わる。
- Debug／instrumentation APKのビルド、単体テスト153件、Lint、エミュレーター上のモデルテスト1件が成功。
- モデルテストは短文と長文のWAVヘッダー・非無音・分割動作を確認。聞き取りや読みの正しさは保証しない。
- Debug画面の生成ボタンから合成し、試聴ボタンでMediaPlayerがstartedになることを確認。画面は `android/build/kokoro/prototype-screen.png`。
- Releaseの依存関係にONNX Runtime／Kuromojiが含まれないことも確認。
- 音声ファイルと計測ログは `android/build/kokoro/{short.wav,long.wav,metrics.txt,memory.json}`。

**判断:** 端末内での日本語合成は成立。ただし約632 MiBの観測PSSと初回待ち時間があり、現時点では本番既定音声にはしない。物理端末での評価と日本語前処理改善を次の判断材料にする。

## 本番統合前の判断事項

1. 実機で音を聴き、日本語の読み間違い・抑揚・文間の自然さを評価する。
2. ミドルレンジ端末で初回待ち時間・メモリ・発熱を測る。エミュレーターの測定は実機性能を保証しない。
3. 初回モデルダウンロード・進捗・破損検出・削除UIを用意する。
4. 文章の先読み、停止・再開、スリープタイマー、ユーザー辞書、再生位置との統合を実装する。
5. 配布時はモデルとKuromoji/IPADICのライセンス表示を含める。現状は実験用モデルを別途配置する方式。

## 出典

- [Kokoro ONNXモデル・入力仕様・ライセンス](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX)
- 固定リビジョン: `1939ad2a8e416c0acfeecc08a694d14ef25f2231`
- [ONNX Runtime Java API](https://onnxruntime.ai/docs/get-started/with-java.html)
- [Kuromoji](https://github.com/atilika/kuromoji)

## 2026-10-29の改善

音素列を欠落なく保つ文・句境界の分割、短すぎる末尾の調整、合成停止ボタンと画面を離れた際のキャンセルを追加した。最大120音素とDebug専用の構成は維持している。実モデルの生成・ファイル保全・停止ボタンの3テストを含む検証と試聴音声は [Android音声品質改善](voice-quality-2026-10-29.md) に記録した。
