#!/bin/bash
#
#  ci_ios.sh
#  VoiceYourText
#
#  iOS CI（.github/workflows/ios-ci.yml）で実行するコマンド一式。
#  ローカルでも同じコマンドで再現できるようにスクリプトにまとめている。
#
#  使い方（リポジトリルートから）:
#    iOS/scripts/ci_ios.sh config      # gitignore された Debug.xcconfig をダミー値で生成
#    iOS/scripts/ci_ios.sh simulator   # CI 専用シミュレータを用意して boot（UDID を出力）
#    iOS/scripts/ci_ios.sh build
#    iOS/scripts/ci_ios.sh test
#
#  環境変数:
#    DERIVED_DATA_PATH  DerivedData の置き場所（既定: iOS/build/DerivedData）
#    RESULT_BUNDLE_PATH test の xcresult の出力先（既定: iOS/build/TestResults.xcresult）
#    SIMULATOR_NAME     CI 専用シミュレータ名（既定: CI-VoiceYourText）
#
#  CI は Debug 構成のみ。Release 用の秘密情報（RevenueCat キー・本番 AdMob ID）は扱わない。
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="${REPO_ROOT}/iOS"
PROJECT="${IOS_DIR}/VoiceYourText.xcodeproj"
SCHEME="VoiceYourText"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${IOS_DIR}/build/DerivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-${IOS_DIR}/build/TestResults.xcresult}"
SIMULATOR_NAME="${SIMULATOR_NAME:-CI-VoiceYourText}"
SIMULATOR_DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"
SIMULATOR_RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-27-0"

simulator_udid() {
    xcrun simctl list devices -j | /usr/bin/python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
for device in json.load(sys.stdin)["devices"].get(runtime, []):
    if device["name"] == name and device.get("isAvailable", True):
        print(device["udid"])
        break
' "$SIMULATOR_NAME" "$SIMULATOR_RUNTIME"
}

cmd_config() {
    config="${IOS_DIR}/VoiceYourText/config/Debug.xcconfig"
    if [ -f "$config" ]; then
        echo "Debug.xcconfig は既に存在するので生成しません"
        return 0
    fi
    # AdMob は Google 公式のテストID、その他はダミー値
    cat > "$config" << 'XCCONFIG'
REVENUECAT_API_KEY = REVENUECAT_API_KEY_NOT_SET
ADMOB_BANNER_ID = ca-app-pub-3940256099942544/2435281174
ADMOB_APP_OPEN_ID = ca-app-pub-3940256099942544/5575463023
XCCONFIG
    echo "Debug.xcconfig をダミー値で生成しました"
}

cmd_simulator() {
    udid="$(simulator_udid)"
    if [ -z "$udid" ]; then
        udid="$(xcrun simctl create "$SIMULATOR_NAME" "$SIMULATOR_DEVICE_TYPE" "$SIMULATOR_RUNTIME")"
        echo "シミュレータ ${SIMULATOR_NAME} を作成しました" >&2
    fi
    # 未起動のまま test すると起動待ちでハングする／接続タイムアウトになるので先に boot しておく
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >&2
    echo "$udid"
}

cmd_build() {
    # generic destination だと x86_64 もビルドして倍かかるので、test と同じシミュレータを指定する
    udid="$(cmd_simulator)"
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=${udid}" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -skipMacroValidation \
        -skipPackagePluginValidation \
        CODE_SIGNING_ALLOWED=NO
}

cmd_test() {
    udid="$(cmd_simulator)"
    rm -rf "$RESULT_BUNDLE_PATH"
    # UIテストはロケール×外観の全組み合わせに展開され1時間以上かかるため、ユニットテストのみ。
    # 並列テストのクローンデバイスではアプリ起動に失敗するので無効化する。
    # シミュレータでは AVSpeechSynthesisVoice(language:) が戻らずテストがハングすることがあるため、
    # ジョブの timeout まで待たずにテスト単位のタイムアウトで失敗させる。
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=${udid}" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        -only-testing:VoiceYourTextTests \
        -parallel-testing-enabled NO \
        -test-timeouts-enabled YES \
        -default-test-execution-time-allowance 60 \
        -maximum-test-execution-time-allowance 120 \
        -skipMacroValidation \
        -skipPackagePluginValidation \
        CODE_SIGNING_ALLOWED=NO
}

case "${1:-}" in
    config) cmd_config ;;
    simulator) cmd_simulator ;;
    build) cmd_build ;;
    test) cmd_test ;;
    *)
        echo "usage: $0 {config|simulator|build|test}" >&2
        exit 64
        ;;
esac
