# Kokoro 日本語の文分割合成（2026-10-29）

## 目的と動作

音声合成の従量課金を増やさず、長い日本語の読み上げを改善する。既存の端末内Kokoroを使い、全文のG2P（読み変換）を一度実行してから、最大200文字の音素列に区切って順に推論する。Tokenizerは1文字あたり最大1トークンなので、モデルの510トークン上限にも収まる。

句点・疑問符などの文末を優先し、次に読点相当の空白などを使う。短い文はまとめ、最後だけ極端に短くならないように分割する。句読点・閉じ括弧・空白も元の順番で保ち、全チャンクの結合が元の音素列と一致する。句読点のない長文には長さによる分割が必要となる。

同じ声と速度で合成し、波形を順番に連結する。無音の追加、音量補正、ピッチ変更は本番処理には入れていない。英語の単語タイムスタンプを扱う経路は従来のまま。モデルに渡せる音素がない入力はエラーにして、既存の標準音声へのフォールバックで扱う。

停止・再開・画面を閉じる操作でKokoroのタスクをキャンセルする。処理中の推論が終わった後は次のチャンクを開始せず、部分的な音声も返さない。共有モデルの読み込みタスクは再利用のため維持する。途中エラーは既存の標準音声へのフォールバックに渡す。

公式資料では、多くの声が100〜200トークン付近で良好になり、長すぎる入力では早口になることがあると説明されている。今回の200文字という上限はその目安を基にした実装判断で、自然さの向上を保証する評価結果ではない。

出典: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md （2026-10-29確認）

## 費用と範囲

- 端末上の推論なので追加のクラウド音声合成API料金は発生しない。既存モデルの配信費などは別。
- ユーザーの声・エンジン設定は上書きしない。Kokoroを有効にしている場合に適用される。
- アプリ配信・サーバー変更・クラウド音声の本番導入は実施していない。

## 検証

- Xcode 27.1 / iOS 27.0 / CI-VoiceYourTextシミュレータで最終版のDebugビルド成功。
- 最終版の単体テスト127件成功（KokoroPhonemeChunker 13、JapaneseG2P 20、KokoroEngine 63、KokoroTTSClient 10、VoiceResolver 21）。
- 日本語・英語の保存して聴くUIテスト2件成功。計129件。初回のUI指定はファイル名をクラス名にしてしまい0件だったため、正しいVoiceYourTextUITestsクラスで別途実行し、2件の成功を確認した。
- 変更箇所を明示したSwiftLintはエラー0、警告120。プロジェクト規則で除外される移植コードのエンジン本体は通常のlint対象外。
- 全体SwiftLintは既存の別ファイルで28エラー・914警告。内訳はScreenshotDemoContent+Locales.swiftの長い行2件と、PaywallAnalytics/.build配下の生成コード26件。今回の変更ファイルにエラーはない。
- `git diff --check` 成功。

結果とログ:
- `/tmp/narrator-kokoro-20261029/FinalTests.xcresult`
- `/tmp/narrator-kokoro-20261029/ListeningUITests.xcresult`
- `/tmp/narrator-kokoro-20261029/final-tests.log`
- `/tmp/narrator-kokoro-20261029/ui-tests.log`
- `/tmp/narrator-kokoro-20261029/changed-swiftlint.json`
- `/tmp/narrator-kokoro-20261029/swiftlint.json`

## 試聴と実機確認

同じ167字の物語・jf_alpha・speed 1.0で試聴音声を作成。今回の本番Swift分割関数では343文字の音素列が158・185に分かれ、26.6秒の音声になった。以前の比較Bは157・186で分割していたため、今回の試聴を別ファイルとして保存した。

試聴ファイルは現在のアプリと同じ日本語G2Pと今回のSwift分割関数を使い、MacのPython kokoro 0.9.4 CPUで生成したもの。iPhoneのMLX実録音ではない。比較用ファイルに限り一定ゲインで−22 LUFSにそろえた（ピーク−6.69 dBTP）。主観的な自然さ、文のつなぎ目、iPhoneの合成時間・メモリ・発熱は実機での確認が必要。アプリは全チャンクの合成完了後に再生する。

保存場所:
`/Users/entaku/.codex/visualizations/2026/10/27/01a17adb-fe8b-76a3-93d5-c0726533a078/kokoro-update-2026-10-29/`

- `kokoro-before-preview.wav`: 変更前の全文一括合成
- `kokoro-improved-preview.wav`: 今回の区切り方の合成
- `preview-manifest.json`: 条件と測定値
- `implemented-chunks.json`: 実装から出力した音素列
