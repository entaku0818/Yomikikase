# AdMob delivery measurement — iOS

2026-11-19の変更で、バナーの表示領域に合うadaptiveサイズと、広告の取得・表示までのイベントを追加する。広告枠、課金者の除外、App Openの表示頻度は変更しない。公開済みの版・公開日はリリース後に記録し、分析はそのアプリ版に限定する。

実装: [AdmobBannerView.swift](../../iOS/VoiceYourText/Features/Ads/AdmobBannerView.swift)、[AppOpenAdManager.swift](../../iOS/VoiceYourText/Features/Ads/AppOpenAdManager.swift)。

## バナー

全イベントに次のフィールドを付ける。

| フィールド | 意味 |
| --- | --- |
| `placement` | 表示画面。`home`, `my_files`, `text_input`, `speech`, `settings`, `language_settings`, `pdf_reader`, `pdf_picker`, `simple_pdf_picker`, `pdf_list`。AdMob上の広告ユニットは共通。 |
| `ad_width`, `ad_height` | SDKへ設定した広告サイズ。整数のpoint単位で、画面のpixel数ではない。 |

| イベント | 発火条件 | 追加フィールド |
| --- | --- | --- |
| `ad_banner_requested` | アプリが明示的に`load`を呼ぶ直前。ウィンドウへ接続した同じUIViewで、サイズ・広告ユニットが同じなら重複して要求しない。 | `load_source=app` |
| `ad_banner_loaded` | SDKの広告受信コールバック。まだ実表示を意味しない。 | `load_source`、明示要求の結果なら`load_duration_ms` |
| `ad_banner_load_failed` | SDKの広告取得失敗コールバック。 | `load_source`, `error_code`, `error_domain`。明示要求の結果なら`load_duration_ms` |
| `ad_banner_impression` | SDKの実インプレッションコールバック。 | なし |
| `ad_banner_click` | SDKのクリックコールバック。 | なし |
| `ad_banner_paid` | SDKの収益コールバック。 | `value`, `currency`, `precision` |
| `ad_banner_abandoned` | アプリが観測中の`loading`または`loaded`を、インプレッション前に終了する。 | `phase`, `reason` |

`load_duration_ms`はアプリの明示要求からコールバックまでの経過ミリ秒。`error_code`と`error_domain`は`NSError`の値で、エラーメッセージ、入力テキスト、文書名、広告内容をAnalyticsへ送信しない。

`load_source=app`は未完了の明示要求の結果。`sdk_refresh`は明示要求の計時がない受信・失敗コールバックを指す分類で、SDKから直接提供されるrequest IDや発生元ではない。SDKの自動更新開始はdelegateに通知されないため、`ad_banner_requested`は自動更新要求やSDK・アダプタ内部の再試行を数えない。総リクエスト数やマッチ率はAdMobレポートで確認する。

`ad_banner_abandoned`の`phase`は`loading`（明示要求の完了前）または`loaded`（受信済み・実表示前）。`reason`は次のいずれか。

| `reason` | 意味 |
| --- | --- |
| `view_removed` | SwiftUIがバナーUIViewを破棄。画面遷移のほか、adaptiveサイズ変更に伴うUIViewの置換も含む。両者はこのイベントだけでは区別できない。 |
| `size_or_unit_changed` | 同じUIViewへの明示的な再要求前にサイズか広告ユニットが変わった。通常のサイズ変更はUIView置換になるため`view_removed`として記録されることがある。 |
| `refreshed_before_impression` | 受信済みの広告に実インプレッションがないまま、次の広告受信コールバックが来た。 |

abandonedはSDKリクエストのキャンセルや広告実装の欠陥を断定する値ではない。短い画面滞在、画面遷移、サイズ変更でも発生する。SDK自動更新の開始は観測できず、プロセス終了時の送信も保証されないので、すべての未表示を網羅するカウンタでもない。失敗したSDK自動更新の前に残っていた広告は、引き続き表示される可能性がある。

## App Open

対象は引き続き、オンボーディング完了後の非課金者のcold start、3回に1回。SDK初期化完了後、広告ロードを最大4秒待つ。warm foregroundには広げない。

全イベントの`launch_count`は、その起動で評価したApp Open専用のローカル起動カウンタ。全セッションを一意に識別するIDではなく、他の起動カウンタとも同一ではない。表示・クリック・収益コールバックには、表示開始時の値を引き継ぐ。

| イベント | 発火条件 | 追加フィールド |
| --- | --- | --- |
| `app_open_ad_requested` | アプリが明示的に`load`を呼ぶ直前。 | なし |
| `app_open_ad_loaded` | SDKのロード成功コールバックで広告を受け取った。 | `load_duration_ms` |
| `app_open_ad_load_failed` | SDKのロード失敗コールバック、または広告もエラーもない結果。 | `load_duration_ms`。SDKエラーなら`error_code`, `error_domain`、広告もエラーもなければ`reason=empty_response` |
| `app_open_ad_present_attempt` | 表示可否チェックに成功し、`present`を呼ぶ直前。実表示ではない。 | なし |
| `app_open_ad_present_failed` | 表示可否チェックの例外、またはSDKの表示失敗コールバック。 | `stage=preflight`または`presentation`, `error_code`, `error_domain` |
| `app_open_ad_shown` | SDKの実インプレッションコールバック。 | なし |
| `app_open_ad_click` | SDKのクリックコールバック。 | なし |
| `ad_app_open_paid` | SDKの収益コールバック。 | `value`, `currency`, `precision` |
| `app_open_ad_skipped` | その起動で表示開始まで進まなかった。 | `reason` |

App Openの`load_duration_ms`も明示要求から結果までの経過ミリ秒。リクエストイベントはSDK・アダプタ内部の再試行を個別に数えない。SDK初期化の待ち時間はロード時間に含めない。

`app_open_ad_skipped.reason`は`premium`, `onboarding`, `launch_gate`, `no_unit_id`, `load_failed`, `load_timeout`, `cannot_present`。Appの入口でオンボーディング中などを除外した場合、managerを呼ばないためskipイベント自体が出ないこともある。`load_failed`は待機中にロードが失敗して終了、`load_timeout`は4秒の待機終了時にもロードが続いていた場合。待機終了後に`loaded`が届いても、その起動では後追い表示しない。`stage=presentation`の失敗はすでに表示開始を試した後なので、skipには重複計上しない。

## 変更前のイベントとの比較

変更前の`app_open_ad_shown`は`present`呼び出し前に記録していた。変更後は同じ名前を実インプレッションに限定し、表示試行を`app_open_ad_present_attempt`へ分ける。したがって、変更前後の`shown`件数の差を、そのまま広告の改善・悪化と解釈しない。変更前はロード失敗も`load_timeout`へまとめていたため、skip理由の時系列にも区切りが必要。

バナーのimpression・click・paidとApp Openのpaidは既存イベント。新しいバナーの寸法フィールド、App Open paidの`launch_count`は過去データに存在しない。新イベントがない旧版と新しい版を混ぜたファネルを作らない。

## リリース後の確認

1. 公開版と公開日を記録し、iOS・対象アプリ版・同じ期間・同じ国の条件でイベント到達を確認する。
2. バナーは`placement`とサイズ別に取得失敗、実表示、abandonedのphase/reasonを見る。明示要求だけの取得結果を見る場合はloaded/failedを`load_source=app`に限定する。SDK更新のインプレッションも含む全表示数を、明示要求数だけで割って表示率と呼ばない。
3. App Openは要求→取得→表示試行→実表示を確認し、ロード失敗、待機時間超過、表示失敗を分ける。待機時間超過後のロード成功があるため、loadedとshownの差だけでは欠陥と断定しない。shownとskippedだけでも全起動を網羅しない。
4. AdMobの総リクエスト、マッチ率、表示率、eCPM、推定収益と照合する。GA4のイベント収集範囲・送信遅延が異なるため完全一致を前提にしない。
5. 収益は`currency`別に集計する。`value`はSDKが返すその通貨の金額で、micros単位ではない。`precision`も保持する。収益コールバックがないことをゼロ収益と断定せず、AdMobのインプレッション単位収益設定とイベント到達を確認する。

この変更だけでは収益増加、実機での広告表示、GA4への本番イベント到達は検証されない。継続率・広告以外の課金売上とあわせ、公開後の実績で評価する。
