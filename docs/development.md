# ローカル開発とCI

2026-10-27時点。実行条件の正本は `.github/workflows/`、iOSの実行手順は `iOS/scripts/ci_ios.sh`。

## CIゲート

| ワークフロー | 実行条件 | 環境 | 検証内容 |
| --- | --- | --- | --- |
| `ci.yml` | mainへのpush・main向けPR。`iOS/**`、`.swiftlint.yml`、自身の変更 | Ubuntu、SwiftLint 0.57.0コンテナ | SwiftLint |
| `ios-ci.yml` | 全ブランチへのpush・PR。`iOS/**`、自身の変更。手動実行も可 | `self-hosted, macOS, xcode27` | Debugビルド、アプリ単体テスト、PaywallAnalyticsのSwiftPMテスト |
| `ci-android.yml` | mainへのpush・main向けPR。`android/**`、自身の変更 | Ubuntu、Temurin JDK 17 | Debug APK、単体テスト、Android Lint |
| `ci-functions.yml` | mainへのpush・main向けPR。`functions/**`、自身の変更 | Ubuntu、Node.js 20 | JavaScript構文検証、ESLint |

iOSのself-hostedジョブはフォーク元からのPRでは実行しない。GitHub-hostedのmacOSランナーは使用しない。`xcode27`は専用Macのラベルで、実際のXcodeバージョンはジョブの「Show Xcode version」で確認する。スクリプトはiOS 27.0ランタイムとiPhone 18 Proデバイスタイプを指定している。

Androidの `testDebugUnitTest` は現在有効。Issue #85に記載された `HistoryStoreTest` によるテストスキップは残っていない。iOSのUIテストは通常CIの対象外。Functionsの `npm test` は未実装のプレースホルダーで、CIでも実行しない。

上記以外に `test-server.yml`（serverのTypeScriptビルド・テスト）、`test-cloudrun.yml`（Goビルド・lint・テスト・カバレッジ）、`test-voicevox-server.yml`（gofmt・vet・テスト）がある。`deploy-cloudrun.yml` は検証ではなく、mainへの `cloudrun/**` 変更または手動実行でデプロイするワークフロー。

## iOSの設定

リポジトリルートから、設定ファイルがまだ無い場合だけサンプルをコピーする。

```bash
test -f iOS/VoiceYourText/config/Debug.xcconfig || cp iOS/VoiceYourText/config/Debug.xcconfig.sample iOS/VoiceYourText/config/Debug.xcconfig
test -f iOS/VoiceYourText/config/Release.xcconfig || cp iOS/VoiceYourText/config/Release.xcconfig.sample iOS/VoiceYourText/config/Release.xcconfig
```

| キー | Debug | Release |
| --- | --- | --- |
| `REVENUECAT_API_KEY` | RevenueCatの開発用キー。CIはダミー値 | 本番用キー |
| `ADMOB_BANNER_ID` | サンプルのGoogleテストID | 本番バナー広告ユニットID |
| `ADMOB_APP_OPEN_ID` | サンプルのGoogleテストID | 本番アプリ起動広告ユニットID |

Releaseサンプルの `XXXXXXXXXX` は実際の値に置き換える。Releaseビルドの「Validate AdMob Ad Unit IDs」はテストIDやプレースホルダーを拒否する。`.xcconfig` と `GoogleService-Info.plist` はGit管理対象外なので、Firebaseの実サービスを使用する開発環境では対応するアプリの設定ファイルも用意する。

旧クラウドTTS向けの `AUDIO_API_BASE_URL` と `CLOUDRUN_API_KEY` は現在のiOS設定では不要。後者は旧Cloud Runのデプロイワークフローで使用するGitHub Secretとしては残っている。iOS設定へ追加しない。

## ローカルでCIを再現

以下は検証を実行するコマンド。iOSは上記のXcode・Simulatorランタイム、AndroidはJDK 17とAndroid SDK、FunctionsはNode.jsとnpmが必要。

```bash
# iOS：リポジトリルートで実行
xcodebuild -version
iOS/scripts/ci_ios.sh config
iOS/scripts/ci_ios.sh build
iOS/scripts/ci_ios.sh test
swift test --package-path iOS/LocalPackages/PaywallAnalytics
swiftlint lint --reporter github-actions-logging

# Android：android/で実行
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
./gradlew :app:lintDebug

# Functions：functions/で実行
npm ci
node --check index.js
npm run lint
```

`config` は既存のDebug設定を上書きしない。生成したダミー値はビルド用であり、課金などの実サービス動作確認には実際の設定が必要。

`DERIVED_DATA_PATH`（既定 `iOS/build/DerivedData`）、`RESULT_BUNDLE_PATH`（既定 `iOS/build/TestResults.xcresult`）、`SIMULATOR_NAME`（既定 `CI-VoiceYourText`）でiOSの出力先とシミュレータ名を変更できる。`test` は指定した結果バンドルを削除して再作成するので、残したい結果は別名で保存する。`iOS/build/` 全体は削除しない。

CI失敗時は最初に失敗したステップと同じコマンドを実行する。Simulatorのエラーなら `xcrun simctl list runtimes` で必要なランタイムを確認する。iOSテスト失敗時の結果はActionsの `TestResults-<run id>` artifactから取得できる（結果が作成された場合）。パッケージ解決失敗時はスクリプトが対象DerivedData内のSourcePackagesを削除して一度再試行する。

Functionsの実行時設定とデプロイ前の確認は [functions/README.md](../functions/README.md) を参照。
