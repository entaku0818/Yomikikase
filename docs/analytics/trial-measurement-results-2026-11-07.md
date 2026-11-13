# トライアル仮説の追加データ・計測（2026-11-07）

## 既存データの追加集計

BigQuery `voiceyourtext.analytics_431236332`、iOS。購入成功の対象はUTC 2026-10-01〜11-01未満、観測終了はUTC 2026-11-07 00:00。購入後8日までを観測。生ID・本文は出力せず、集計のみを取得した。

**これは試用者コホートではない。** `subscription_purchase_success` の6インストール（7イベント）を、各インストールの期間内最初の購入成功から追った参考集計。同じ人の複数端末や再インストールは別識別子になり得る。RevenueCatの10月開始7試用とは未結合。

| 項目 | 観測結果 |
|---|---:|
| 購入成功を記録したインストール | 6 |
| 24時間以降〜8日未満のsession_startあり | 0/6 |
| 同期間のいずれかのイベントあり | 0/6 |
| D1（24〜48時間）の再訪 | 0/6 |
| D3（72〜96時間）の再訪 | 0/6 |
| D7（168〜192時間）の再訪 | 0/5（1件は観測期間不足） |
| 購入後の旧/新読み上げ完了イベントあり | 2/6 |
| 購入後の新content_playback_requestedあり | 0/6 |
| 購入後VOICEVOXをONにした記録あり | 2/6 |

再訪以外の件数も最大8日までの観測で、全員が同じ長さの期間を満たすわけではない。完了イベントは既知の経路欠測がある。トグルは実再生の証拠ではない。利用が少ない層と計測の欠測が重なっている可能性を残す。

購入成功7イベントの内訳は月額5回・年額2回、trial_eligible=trueが5回・パラメータなしが2回。導線はunknown 4回、旧subscription_view 2回、pdf_simple_upgrade_link 1回。バージョンは1.4.1（2回）、1.4.8（2回）、1.4.9（2回）、1.4.10（1回）。debug_modeは全件未設定だったが、本番ストア取引である証明にはならない。試用適格性は試用開始の確定ではない。

### 仮説への示唆

- H1「用途が定着しない」を支持する参考材料が増えた。session_startだけでなく、24時間以降のいずれのイベントも観測されなかった。
- 一方、H2「初日に失敗して戻らない」でも同じ観測結果になる。再生失敗の計測不足によりH1とH2はまだ分けられない。
- H3「終了後も無料で継続」はこの参考コホートの8日以内では支持されないが、試用者との未結合・観測期間・計測欠測から否定しない。
- H4「価格」や「請求失敗」はこのGA4集計では判定不能。購入導線のunknownが多く、自動案内による試用増加を原因と断定しない。

RevenueCatはサンプル顧客のsubscriptions/attributes/events各APIがHTTP 200を返すことまで確認した（そのサンプルは各0件）。対象試用者の履歴内容・結合属性の存在は未確認。

## 今後の追加計測（ローカル実装、未公開）

### 契約と行動の結合

- RevenueCatの現在のappUserIDから `SHA256("voiceyourtext:rc:v1:" + appUserID)` を計算し、GA4のuser_idに設定する。匿名化ではなく**仮名化された結合キー**であり、分析時はアクセス制限する。
- Firebase App Instance IDをRevenueCatの公式属性に設定する。アプリ起動とCustomerInfo適用時に同期し、復元等でIDが変わった場合も更新する。RevenueCatのログイン・契約ID自体は変更しない。
- 設定直前のイベント、旧バージョン、Analytics未送信、再インストールやaliasesは欠損・重複として集計する。連携キー導入で過去のNULL user_idが埋まるわけではない。
- `trial_measurement_version=1` と `build_environment=debug/release` を設定。ストアのsandbox/productionとは別に扱う。
- RevenueCat→GA4のサーバーイベント連携の有効化はこのコード変更だけでは完了しない。非再訪者の解約・失効・初回請求は、RevenueCatの既存履歴またはサーバー連携が引き続き必要。

### 契約状態の観測

`subscription_status_observed` は検証済みCustomerInfoを適用できた時点のactive/period_type/will_renew/billing_issue/unsubscribe_detected/store_environmentを記録する。実際の試用期間種別はCustomerInfoから取り、購入前の適格性と混同しない。

これはアプリ利用時点のスナップショット。トライアル開始・有料請求・解約の発生イベントではなく、件数を購入回数にしない。アプリに戻らない人の結果は取得できず、キャッシュされた状態の可能性もある。

### 再生の観測

TextInputViewのテキスト・スキャン・EPUB・青空文庫・保存済み音声経路に追加。既存request/completedイベントを維持し、再生試行ごとのランダムattempt_idで連結する。

| イベント | 意味 |
|---|---|
| content_playback_requested | 読み上げ要求を受け付けた |
| content_playback_engine_selected | device/kokoro/voicevox/saved_audio/resumed_audioの経路を選んだ |
| content_playback_progress | 選択エンジンごとの最初の進行信号。request_to_progress_msとevidenceを記録 |
| content_playback_failed | audio_session/synthesis/audio_player/quotaの固定分類とrecoveringフラグ |
| content_playback_stopped | user/view_closed/interruptedの固定分類 |
| content_playback_completed | 今回要求した文章または残りの文章の完了 |

- evidence=player_acceptedはAVAudioPlayer.play()成功、text_highlightは端末TTSのハイライト通知、sentence_scheduledはVOICEVOXの文通知。音が聞こえたことの証明ではなく、VOICEVOX文通知は実音声開始より前の場合がある。request_to_progress_msを初音声までの時間と呼ばない。
- engineの切り替え（フォールバック）は同じattempt_idを維持し、失敗したエンジンと最終エンジンを区別する。
- 文字数はup_to_500/501_to_4000/over_4000の粗い区間のみ。元の全文の長さであり、再開後に実際に聴いた量ではない。本文・ファイル名・ファイルID・生エラー文字列を送信しない。
- 遅い通知・停止後の通知・完了の多重発火を無視する。手動停止と失敗を区別する。
- **PDFReader/NowPlayingの全経路は今回の追加イベント対象外。** 旧speech_completedと混在させず、coverageを限定して分析する。モデルダウンロード専用の開始/完了、音声品質の主観評価、価格への不満はこれだけでは測れない。

## 再現方法

既存ADC認証とrequestsを使用。読み取りスクリプトはdry runで単一SELECTを確認し、100MB上限とページング・未完了結果の検出を行う。実行はそれぞれ約2.6MB、2.8MBの推定読み取りだった。

```bash
python3 scripts/analytics/run_readonly_query.py scripts/analytics/trial_purchase_usage.sql
python3 scripts/analytics/run_readonly_query.py scripts/analytics/trial_purchase_coverage.sql
```

## 残る作業

- RevenueCatの対象限定分析は、ユーザー承認後、生IDを一時保存しない方式で完了した（下記追記）。集計値だけを保存。過去GA4との個別結合は引き続き未達。
- 本番ユーザーの計測開始は、ビルド検証・公開・公開版でのイベント受信確認後。実装しただけではデータは増えない。
- 実機/DebugViewで、試用開始→再生成功・失敗・停止→復元、GA4の結合キーとRC属性を照合。test/sandbox/debugは本番評価から除外。
- 公開後は成熟した試用者だけで評価する。まず結合率・イベント送信率を確認し、欠測は未利用にしない。
- 価格・用途の主観的な理由が残る場合は、任意の理由回答を収集する施策を別途検討する。今回ユーザーへ連絡・アンケート送信は行っていない。

## 検証結果

- Xcode 27.1 / CI-VoiceYourTextでアプリ・テストのビルド成功。
- TextListeningTests 7件、PlaybackResumeTests 14件、合計21件が成功（0 failures）。最終結果: iOS/build/Issue163-Analytics-Final-20261107.xcresult。
- 初回検証は文字数区間追加前のビルドと更新後のテストの不一致で失敗。最終ソースを再ビルドして上記全件成功を確認した。
- 変更したSwift 6ファイルのSwiftLintはエラーなし（スタイル警告あり）。差分の空白検査とPython構文検査も成功。
- 集計SQL2本を、単一SELECTの確認・100MB上限付きで実行成功。結果はtrial-purchase-usage-20261107.jsonとtrial-purchase-coverage-20261107.json。
- 本番/DebugViewでのイベント到達・実機音声は未検証。コミット・push・リリースはしていない。


## 承認後のRevenueCat追加分析 — 2026-11-07 23:46 JST

顧客一覧は抽出のためにのみ参照。3,537件から、9/1以降にlast_seenがあり11/7 UTCより前にfirst_seenがある499件を候補として、productionの契約イベントを取得した。App StoreのINITIAL_PURCHASEかつperiod_type=TRIAL、開始時刻がUTC 9/1以上11/7未満の対象だけを集計した。

対象試用14件すべてにoriginal_transaction_idがあり、同じ取引系列のイベントだけで失効・決済失敗等を判定した。transaction_idで重複排除。開始件数（9月3、10月7、11/1〜6は4）は既存Charts集計と一致する。last_seenによる候補絞り込みを使っているため、取得対象の完全性をこの一致以上に保証するものではない。

生の顧客ID・取引ID・Firebase ID・レスポンス・メール等はファイルに保存していない。読み取り中のメモリだけで扱い、保存したのは [月別集計](trial-contract-summary-20261107.json) のみ。属性は対象試用者に限定して読み、公式のFirebase App Instance ID属性の有無だけを集計した。

| 開始月 | 試用開始 | 有料転換通知 | 更新停止による失効 | 決済失敗による失効 | 未失効・予定終了前 |
|---|---:|---:|---:|---:|---:|
| 9月 | 3 | 0 | 3 | 0 | 0 |
| 10月 | 7 | 0 | 6 | 1 | 0 |
| 11月1〜6日 | 4 | 0 | 0 | 0 | 4 |

9〜10月はEXPIRATIONのexpiration_reasonがUNSUBSCRIBE 9件、BILLING_ERROR 1件。10月の1件にはBILLING_ISSUE通知もある。更新停止や失効だけを有料転換失敗の原因と一括りにせず、決済失敗を別枠にする。

最初のCANCELLATION記録は、9月に開始後1〜24時間が1件・24時間以降が2件、10月7件と11月4件はすべて24時間以降。ここでいう時刻はRCイベントのevent_timestamp_msであり、ユーザーが実際にストアで操作した正確な時刻ではない。開始直後の衝動的な取消を主因とする証拠にはならない。

11月の4件にもUNSUBSCRIBEのCANCELLATION通知があるが、予定試用終了前で失効も有料転換も未記録。更新再開の可能性があるため、将来の転換0件を確定扱いしない。この集計は通知履歴の有無であり、最新のwill_renewを確定するものでもない。

### 利用データとの結合結果

対象14件の現在のRC属性には、公式の$firebaseAppInstanceIdが0件だった。既存コードにも連携処理がなく、GA4側の確認対象イベントではuser_idがNULLだった。今回は確実な結合を成立させられず、RC14件とGA4の購入成功6インストールは別コホートとして報告する。日時やプランが似ているだけの推測結合はしない。過去イベントに別の決定的対応記録が残っている可能性までは否定しない。

### 仮説の更新

- **H4b 決済失敗**: 9〜10月の10件中1件で直接の証拠あり。継続意欲の有無は判定できないが、技術的な請求失敗が実在する。
- **H1 用途が定着しない**: GA4参考集団の再訪なしという材料は維持。ただしRC試用者と未結合なので、更新停止9件の理由として確定できない。
- **H2 価値を体験できない/不具合**: H1と区別できる過去計測が不足。新しい再生計測の公開・到達確認が必要。
- **H3 無料で十分 / H4a 価格や契約条件**: 更新停止理由UNSUBSCRIBEからは区別できない。利用履歴の結合と、必要なら任意の理由回答が必要。

次の優先は、新計測を公開し、RCとGA4の結合率および再生イベントの到達率を確認すること。その後、試用開始から終了まで観測した集団で再訪・再生失敗・無料範囲の利用・課金結果を比較する。追加した計測だけで主観的な価格不満まで断定できるとは扱わない。

再現用スクリプト: scripts/analytics/collect_trial_contracts.py。集計のみ標準出力し、生データは保存しない。契約結果は取得時点で変化し得るため、再実行時は取得日時も併記する。

## 計測版の審査提出 — 2026-11-08 JST

1.4.13 build 50に計測変更を含め、アーカイブ・署名・IPA検証とアップロードが成功。既存のbuild 49から差し替えて審査へ提出した。承認後自動公開を設定。公開版の受信確認は未実施。過去の未公開との記述は実装時点の状態。詳細: [リリース記録](../releases/trial-measurement-1.4.13-50/README.md)。
