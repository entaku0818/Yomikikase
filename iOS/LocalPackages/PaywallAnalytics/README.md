# PaywallAnalytics

課金画面のイベント名・導線値・自動表示条件を共有するSwiftパッケージ。Firebase、RevenueCat、TCA、MLXには依存せず、Simulatorや音声モデルなしで `swift test` を実行できる。イベントを構築するだけで、送信や購入処理はアプリ側が担う。

## APIと組み込み

XcodeのVoiceYourTextターゲットからローカルパッケージとして参照する。利用例は `Features/Settings/SubscriptionView.swift`。

```swift
import PaywallAnalytics

let event = PaywallAnalyticsEvent.paywallView(source: .settings)
// アプリ側のAnalyticsClientへ event.name / event.parameters を渡す。
let purchase = PaywallAnalyticsEvent.purchase(
    .success, source: .settings, planType: "monthly", isTrialEligible: true
)
```

`PaywallSource` の現在の値は `home_file_limit`, `text_char_limit`, `pdf_picker_limit`, `pdf_simple_limit`, `pdf_simple_upgrade_link`, `pdf_list_limit`, `settings`, `voicevox_quota`, `voicevox_picker`, `voicevox_settings`, `onboarding_trial`, `monthly_prompt`, `unknown`。`init(rawSource:)` は未知の文字列を `unknown` にする。

`purchase` はsuccess/cancelled/failed別のイベントを構築する。`AutoPaywallPolicy` はオンボーディング後の一度きりの案内と、30日間隔・インストール後3日の猶予を持つ案内を判定する。保存済み日時、課金状態、再生状態、広告表示状態は呼び出し側から渡す。

## 検証

リポジトリルートで `swift test --package-path iOS/LocalPackages/PaywallAnalytics` を実行する。Swift tools 5.9、対応プラットフォームはiOS 16+ / macOS 13+。イベント値の追加・変更時はケース一覧とテストも更新する。
