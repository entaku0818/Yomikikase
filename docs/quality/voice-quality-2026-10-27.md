# 端末音声の品質選択改善（2026-10-27）

## 問題と変更

保存済みの音声を指定した再生は既に `VoiceResolver` を通っていたが、未選択・削除済み・言語不一致の場合は `AVSpeechSynthesisVoice(language:)` の既定音声に戻るだけだった。ダウンロード済みの Enhanced / Premium を品質で比較していなかった。初回オンボーディングの試聴もこの共通処理を使っていなかった。

- 有効な保存済み音声は引き続き最優先。標準品質の声やパーソナルボイスを明示選択した場合も維持する。
- 未選択時は、OS が解決した音声と同じ言語・地域の候補から、より高品質の音声を選ぶ。Premium > Enhanced > Default。同品質なら OS の既定を維持し、同順位のアップグレード候補は identifier 順で安定させる。
- 自動選択では novelty / personal voice を候補から除外する。既定がこれらなら維持する。高品質音声が無い・取得に失敗した場合は既定音声を使う。
- 自動選択結果は UserDefaults に書き込まない。再生開始時に端末の音声一覧を見直すので、追加ダウンロード後も反映される。
- 通常の端末音声再生と初回試聴で同じ選択処理を使う。音声設定のチェックマーク・音声名・品質表示も実際に解決された声に合わせる。

Apple の品質区分と音声属性は [AVSpeechSynthesisVoiceQuality](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoicequality) およびローカル Xcode SDK の `AVSpeechSynthesis.h` で確認した。

## 効果の範囲

高品質音声がダウンロード済みで、声を明示選択していない端末が対象。未ダウンロードの端末に新しい音声を提供する変更ではない。Kokoro・VOICEVOX・保存済み音声ファイルの声質は変わらない。波形加工、速度・ピッチの変更、新しいクラウド契約は行っていない。

品質区分による選択改善であり、自然さの向上を実機の聴感で検証したわけではない。

## 実機での比較手順

1. 同じ iPhone、同じ音量、標準速度・標準ピッチで端末音声を選ぶ。
2. 標準品質と高品質の声を同じ文章で聴き比べる。
3. 次の文章で自然さ、数字・固有名詞の読み、文末の間、聴き疲れを評価する。

   「今日は、読みかけの記事を耳で楽しみましょう。2026年10月27日、午後3時30分に東京駅で待ち合わせです。資料のPDFは、あとで共有します。」

4. 未選択状態で高品質音声を追加した後、アプリに戻って実際の声・表示が一致することを確認する。

## 検証

- Xcode Debug ビルド成功、関連ユニットテスト 52 件成功（VoiceResolver / Onboarding / HighQualityVoiceGuide / SpeechSynthesizerClientDictionary / SettingsReducer）。
- 日本語・英語の初回試聴完了 UI テスト 2 件成功。合計 54 件、失敗 0 件。
- 追加した 7 テストでは品質順位、音声未ダウンロード、地域・文字体系の維持、言語タグの表記揺れ、同品質維持、候補順序への非依存、個人・特殊音声の除外を確認。
- 変更した本体 Swift ファイルの SwiftLint: エラー 0、スタイル警告 45。`git diff --check` 成功。
- ローカル記録: `/tmp/narrator-voice-quality/QualityTests.xcresult`、`QualityUITests.xcresult`。iOS 27.0 の CI-VoiceYourText シミュレータを使用。
- 実機の Enhanced / Premium 音声での聴感比較と追加ダウンロード後の確認は未実施。コミット・配信は行っていない。
