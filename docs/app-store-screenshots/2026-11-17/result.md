# 1.4.15（53）スクリーンショット更新結果

2026-11-17、全50言語のiPhone・iPad画像を各3枚から6枚へ増やし、App Store審査に提出した。提出後の実APIで **WAITING_FOR_REVIEW** を確認。公開方法は既存のAFTER_APPROVAL（承認後自動公開）を保持した。現在の公開版は1.4.14で、公開中の画像は審査承認まで従来構成のまま。

- バージョンID: `696085e1-1091-4e04-85a9-dd127fd716ae`
- ビルドID: `82e1363a-7272-4ac9-8be4-97ec91a4a020`（53、VALID）
- 提出ID: `fcc92cd5-b9e4-4553-99c3-dd70da92254e`
- 提出状態の取得時刻: `2026-11-17T13:28:22Z`

## 更新範囲

| 対象 | 言語 | 各言語の枚数 | 合計 | 寸法 |
|---|---:|---:|---:|---|
| iPhone | 50 | 6 | 300 | 1320 × 2868 |
| iPad | 50 | 6 | 300 | 2048 × 2732 |

各言語・端末の1〜6枚目すべてを新構成へ更新。順序は「読み上げ中 → ホーム → 速度調整 → PDF → スリープタイマー → ユーザー辞書」。再生中の実画面を1枚目とし、実際のハイライト箇所の画像を拡大している。日本語の6枚プレビューはユーザー確認済み。画像の保存コミットは1言語ごとに分割した。

[全言語・端末のプレビュー](gallery.html)／[確認済みの日本語6枚](preview/ja-six-screens.png)

検索結果用50件とヘッダー50件の配置は保持。公開版1.4.14の400配置（スクショ300件＋クリエイティブ100件）は変更前と一致した。新しい1.4.15はスクショ600件＋クリエイティブ100件。ヘッダー・検索結果の元の設定作業は `docs/creative-assets/2026-11-17/` を参照。

## 検証

- 全600枚のRGB形式・寸法・SHA-256を検証。Git管理する画像と最終生成物も600枚すべて一致。
- 提出前と提出後の両方で、全50言語・各端末6枚の画像IDと順序を実APIで照合。
- Apple CDNから全600枚を取得し、元画像と画素が完全一致。
- ChromeのApp Store Connectで、日本語・英語それぞれのiPhone大型ディスプレイ／iPad 13インチが6/10で、実画像と順序も一致することを確認。ヘッダーは両言語とも実画像と1/1を確認。iPhone中型ディスプレイには大型サイズの画像が継承される。
- ローカライズ検証: 50言語・403エントリ、0エラー。キャプションは既存翻訳を再利用し、文字体系・RTL・はみ出しを検査。全言語をネイティブ話者が再翻訳レビューしたという意味ではない。
- アプリ単体テスト: 546件、失敗0、3件スキップ。PDF修正後にも再実行済み。PaywallAnalytics: 22件、失敗0。
- SwiftLint 0.65.1: エラー0、警告830。キャッシュを使わず実行。
- Debug撮影用の固定データと再生状態を使用。Release実行ファイルにScreenshotPlaybackFixtureが含まれないことを確認。撮影によって実音声の品質を検証したとはしていない。

公開App Storeやユーザー端末での新バージョン表示は、まだ確認していない。審査提出・登録・API照合・ASC画面確認の範囲である。

## 配布ビルド

撮影で、親のミニプレイヤー更新時にPDFのStoreが再生成され、読み込み中に戻る問題を検出。PDFReaderPresentationが表示期間中Storeを保持する修正を加えた。修正前のビルド52は保持し、修正後の53を配布対象として選択した。

- 配布ソースの基準コミット: `7416fac`（その後の変更は撮影画像・登録処理・証跡）
- Releaseアーカイブ／IPA書き出し／アップロード成功。Apple側のVALIDを確認。
- IPA署名を検証し、bundle ID・1.4.15（53）・get-task-allow=falseを確認。
- IPA SHA-256: `a99cb4e0ab35aa6b4d9095d9eb10bf5ce5d7f744ecc847f38857aa38aae52b7b`

アーカイブは `iOS/build/VoiceYourText-1.4.15-53.xcarchive`、IPAは `iOS/build/export-1.4.15-53/VoiceYourText.ipa`。ビルド52、元の300枚のバックアップ、撮影・合成結果、テスト結果、ログも `iOS/build/` に保持した。

## 証跡

`manifest.json` は600枚のハッシュ、`upload-checkpoint.json` は画像ID、`placement-checkpoint.json` は全100組の配置ID。`verification.json`、`download-verification.json`、`post-submission-screenshot-verification.json` が全件照合結果。`submission.json` と `release-status.json` が提出後の状態。`draft-ui-verification.json` は日英の画面確認範囲、`local-validation.json` と `archive-verification.json` はローカル検証・IPA検証結果を記録する。
